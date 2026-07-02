using Alor.Core;
using System.Collections.Concurrent;
using System.Threading.Channels;
using Terex.OrderGenerator.Configuration;
using Terex.OrderGenerator.Data;
using Terex.OrderGenerator.Models;
using Terex.OrderGenerator.Services.Interfaces;
using Warp.Common.Models;
using Warp.Common.Models.CommandPipeline;
using Warp.Common.Models.CommandPipeline.Base;

namespace Terex.OrderGenerator.Services;

/// <summary>
/// Маркетмейкер по целевым ценам Aloria Director: перечитывает
/// director.price_targets на лету и котирует лестницу заявок вокруг цели —
/// рынок «дышит» и движется за экономическим миром без рестартов сервисов.
/// Существующие генераторы не затронуты; без конфига Terex::TargetGenerator
/// этот генератор выключен.
/// </summary>
[System.Diagnostics.CodeAnalysis.SuppressMessage(
    "Security",
    "CA5394:Do not use insecure randomness",
    Justification = "Randomness is here to generate liquidity on test exchanges, so there is no sense of cryptographic security here.")]
internal sealed class TargetPriceCommandsGenerator : ICommandsGenerator
{
    private const string Client = "GEN";

    private readonly TargetGeneratorOptions? _options;
    private readonly Exchange _exchange;
    private readonly IInstrumentsDataProvider _instrumentsDataProvider;
    private readonly ITargetsDataProvider _targetsDataProvider;
    private readonly IAlorLogger _logger;
    private readonly Random _random = new();

    /// <summary>Актуальные цели (обновляются фоновым циклом).</summary>
    private readonly ConcurrentDictionary<string, TargetInfo> _targets = new();

    /// <summary>Локальная середина котирования по инструменту.</summary>
    private readonly ConcurrentDictionary<string, decimal> _mids = new();

    private readonly ConcurrentDictionary<string, CancellationTokenSource> _activeTasks = new();

    public TargetPriceCommandsGenerator(
        GeneratorOptions options,
        IInstrumentsDataProvider instrumentsDataProvider,
        ITargetsDataProvider targetsDataProvider,
        IAlorLogger logger)
    {
        _options = options.TargetGeneratorOptions;
        _exchange = options.ExchangeModeSettings.Exchange;
        _instrumentsDataProvider = instrumentsDataProvider;
        _targetsDataProvider = targetsDataProvider;
        _logger = logger;
    }

    public async Task StartGeneratingAsync(ChannelWriter<OrderCommandBase> writer,
        CancellationToken cancellationToken)
    {
        if (_options is null)
        {
            _logger.Info("TargetPriceCommandsGenerator disabled (no Terex::TargetGenerator settings).");
            return;
        }

        try
        {
            _ = RefreshLoopAsync(writer, cancellationToken);
            await Task.Delay(Timeout.Infinite, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            _logger.Info("TargetPriceCommandsGenerator cancelled.");
        }
        finally
        {
            StopAllTasks();
        }
    }

    /// <summary>Фоновый цикл: перечитывает цели и инструменты, управляет задачами по инструментам.</summary>
    private async Task RefreshLoopAsync(ChannelWriter<OrderCommandBase> writer, CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var targets = await _targetsDataProvider.GetAllAsync(cancellationToken);
                foreach (var t in targets)
                    _targets[t.Symbol] = t;

                var instruments = await _instrumentsDataProvider.GetAllAsync();
                var quotable = instruments
                    .Where(i => _targets.TryGetValue(i.Symbol, out var t) && t.Active)
                    .ToArray();

                var actualSymbols = quotable.Select(i => i.Symbol).ToHashSet();
                foreach (var symbol in _activeTasks.Keys.Except(actualSymbols).ToList())
                {
                    if (_activeTasks.TryRemove(symbol, out var cts))
                    {
                        await cts.CancelAsync();
                        cts.Dispose();
                    }
                }

                foreach (var instrument in quotable)
                {
                    if (_activeTasks.TryAdd(instrument.Symbol, new CancellationTokenSource()))
                    {
                        var cts = _activeTasks[instrument.Symbol];
                        _ = Task.Run(async () =>
                        {
                            using var linked = CancellationTokenSource
                                .CreateLinkedTokenSource(cancellationToken, cts.Token);
                            await QuoteLoopAsync(instrument, writer, linked.Token);
                        }, cancellationToken);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception e)
            {
                _logger.Error("TargetPriceCommandsGenerator refresh failed", e);
            }

            await Task.Delay(TimeSpan.FromSeconds(_options!.TargetsRefreshSeconds), cancellationToken);
        }
    }

    private async Task QuoteLoopAsync(InstrumentInfo instrument,
        ChannelWriter<OrderCommandBase> writer, CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(
                        _random.Next(_options!.MinIntervalMs, _options.MaxIntervalMs), cancellationToken);

                    if (!_targets.TryGetValue(instrument.Symbol, out var target) || !target.Active)
                        continue;

                    foreach (var command in BuildQuotes(instrument, target))
                        await writer.WriteAsync(command, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (ChannelClosedException)
                {
                    break;
                }
                catch (Exception e)
                {
                    _logger.Error($"Target quoting error for {instrument.Symbol}", e);
                    await Task.Delay(1000, cancellationToken);
                }
            }
        }
        finally
        {
            _activeTasks.TryRemove(instrument.Symbol, out _);
        }
    }

    /// <summary>
    /// Одно котирование: середина тянется к цели (+шум), вокруг — лестница
    /// лимиток, изредка рыночная заявка-тейкер в сторону цели.
    /// </summary>
    private IEnumerable<OrderCommandBase> BuildQuotes(InstrumentInfo instrument, TargetInfo target)
    {
        var step = instrument.MinPriceIncrement;
        if (step <= 0) yield break;

        var mid = _mids.GetOrAdd(instrument.Symbol,
            _ => Quantize((instrument.HighLimitPrice + instrument.LowLimitPrice) / 2, step));

        // Гравитация к цели: доля разрыва, но не больше MaxStepTicks шагов.
        var gap = target.TargetPrice - mid;
        var pull = gap * _options!.PullFactorPct / 100m;
        var maxPull = _options.MaxStepTicks * step;
        pull = Math.Clamp(pull, -maxPull, maxPull);

        var noise = step * _random.Next(-_options.NoiseSteps, _options.NoiseSteps + 1);
        mid = Quantize(mid + pull + noise, step);

        // Спред из дневной волатильности; кламп середины внутрь коридора.
        var spread = Math.Max(
            2 * step,
            Quantize(mid * target.SigmaDaily * _options.SpreadSigmaFactorPct / 100m, step));
        var half = spread / 2;
        mid = Math.Clamp(mid,
            instrument.LowLimitPrice + spread,
            Math.Max(instrument.LowLimitPrice + spread, instrument.HighLimitPrice - spread));
        _mids[instrument.Symbol] = mid;

        var client = new OrderClient(Client, Client, Client, _exchange);

        // Лестница лимиток: у цели плотнее и объёмнее, дальше — реже.
        for (var level = 0; level < _options.DepthLevels; level++)
        {
            var offset = half + level * _options.LevelStepTicks * step;
            var bidPrice = Quantize(mid - offset, step);
            var askPrice = Quantize(mid + offset, step);
            var qtyScale = _options.DepthLevels - level;

            if (bidPrice >= instrument.LowLimitPrice)
            {
                yield return new AddLimitOrderCommand(Guid.NewGuid(), _exchange, instrument.Board, false, bidPrice)
                {
                    Symbol = instrument.Symbol,
                    Quantity = _random.Next(1, _options.MaxLimitQuantity) * qtyScale,
                    Side = Side.Buy,
                    TimeInForceType = TimeInForceType.OneDay,
                    ValidTill = DateTime.Today.AddDays(1),
                    Client = client,
                };
            }

            if (askPrice <= instrument.HighLimitPrice)
            {
                yield return new AddLimitOrderCommand(Guid.NewGuid(), _exchange, instrument.Board, false, askPrice)
                {
                    Symbol = instrument.Symbol,
                    Quantity = _random.Next(1, _options.MaxLimitQuantity) * qtyScale,
                    Side = Side.Sell,
                    TimeInForceType = TimeInForceType.OneDay,
                    ValidTill = DateTime.Today.AddDays(1),
                    Client = client,
                };
            }
        }

        // Тейкер: чем дальше цель, тем вероятнее рыночная заявка в её сторону —
        // «съедает» устаревшие уровни и двигает последнюю цену сделки.
        var gapRatio = mid == 0 ? 0 : Math.Abs(gap) / mid;
        var takerProb = Math.Min(0.35, _options.TakerProbPct / 100.0 + (double)gapRatio * 2.0);
        if (_random.NextDouble() < takerProb)
        {
            var side = gap > 0 ? Side.Buy : gap < 0 ? Side.Sell
                : (_random.Next() % 2 == 0 ? Side.Buy : Side.Sell);
            yield return new AddMarketOrderCommand(Guid.NewGuid(), _exchange, instrument.Board, false)
            {
                Symbol = instrument.Symbol,
                Quantity = _random.Next(1, _options.MaxMarketQuantity),
                Side = side,
                TimeInForceType = TimeInForceType.FillOrKill,
                Client = client,
            };
        }
    }

    /// <summary>Квантование к шагу цены (decimal, без int-кастов: дробные шаги в порядке).</summary>
    private static decimal Quantize(decimal price, decimal step)
        => Math.Max(step, Math.Round(price / step, MidpointRounding.AwayFromZero) * step);

    private void StopAllTasks()
    {
        foreach (var kvp in _activeTasks)
        {
            kvp.Value.Cancel();
            kvp.Value.Dispose();
        }
        _activeTasks.Clear();
    }
}
