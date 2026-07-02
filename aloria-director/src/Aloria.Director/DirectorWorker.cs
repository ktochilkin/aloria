using Aloria.Director.Adapters;
using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;

namespace Aloria.Director;

/// <summary>
/// Боевой tick-loop: каждые TickSeconds двигает мир на тик, пишет целевые цены
/// в Postgres terex, публикует новости/макро/календарь в aloria-api и сохраняет
/// снимок мира (рестарт сервиса продолжает мир, а не начинает заново).
/// </summary>
public sealed class DirectorWorker : BackgroundService
{
    private readonly DirectorOptions _options;
    private readonly TerexDb? _db;
    private readonly AloriaApiPublisher? _apiPublisher;
    private readonly INarrator _narrator;
    private readonly ILogger<DirectorWorker> _log;

    private WorldEngine? _engine;
    private readonly SemaphoreSlim _engineLock = new(1, 1);

    public DirectorWorker(
        DirectorOptions options,
        INarrator narrator,
        ILogger<DirectorWorker> log,
        TerexDb? db = null,
        AloriaApiPublisher? apiPublisher = null)
    {
        _options = options;
        _narrator = narrator;
        _log = log;
        _db = db;
        _apiPublisher = apiPublisher;
    }

    /// <summary>Снимок мира для админки.</summary>
    public WorldSnapshot? CurrentSnapshot => _engine?.Snapshot();

    public WorldState? CurrentState => _engine?.State;

    /// <summary>Ручной рычаг макроцикла — единственный ручной в мире.</summary>
    public async Task<bool> ForceRegimeAsync(Regime regime)
    {
        if (_engine is null) return false;
        await _engineLock.WaitAsync();
        try
        {
            var m = _engine.State.Macro;
            m.Regime = regime;
            m.RegimeAgeDays = 0;
            m.RegimePlannedDays = RegimeMachine.SampleDuration(regime, new Rng(_options.Seed ^ Environment.TickCount));
            if (regime is Regime.Recovery or Regime.Expansion) m.Crisis = false;
            return true;
        }
        finally
        {
            _engineLock.Release();
        }
    }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        var config = new WorldConfig { Seed = _options.Seed, TicksPerDay = _options.TicksPerDay };

        WorldPersistDto? restored = null;
        if (_db is not null)
        {
            await _db.EnsureDirectorSchemaAsync(ct);
            await _db.SeedInstrumentsAsync(ct);
            restored = await _db.LoadWorldStateAsync(ct);
        }

        _engine = new WorldEngine(config, restored);
        _log.LogInformation(
            "Мир {Mode}: день {Day}, тик {Tick}, режим {Regime}",
            restored is null ? "создан" : "восстановлен",
            _engine.State.Day, _engine.State.TickOfDay, _engine.State.Macro.Regime);

        // Полное состояние календаря публикуем на старте.
        if (_apiPublisher is not null)
        {
            await _apiPublisher.PublishCalendarAsync(
                _engine.State.Calendar.Where(c => !c.Done).ToList(), ct);
            await _apiPublisher.PublishMacroAsync(_engine.Snapshot(), ct);
        }

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(_options.TickSeconds));
        do
        {
            try
            {
                await _engineLock.WaitAsync(ct);
                TickOutput output;
                try
                {
                    output = await _engine.TickAsync(_narrator, ct);
                }
                finally
                {
                    _engineLock.Release();
                }

                if (_db is not null)
                {
                    await _db.UpsertTargetsAsync(output.Targets, ct);
                    await _db.SaveEventsAsync(output.Events, ct);
                    await _db.SaveWorldStateAsync(_engine.Persist(), ct);
                }

                if (_apiPublisher is not null)
                {
                    await _apiPublisher.PublishNewsAsync(output.News, ct);
                    if (output.MacroChanged)
                        await _apiPublisher.PublishMacroAsync(output.Snapshot, ct);
                    if (output.NewCalendarEvents.Count > 0)
                        await _apiPublisher.PublishCalendarAsync(output.NewCalendarEvents, ct);
                }

                if (output.News.Count > 0 || output.Events.Count > 0)
                    _log.LogInformation(
                        "День {Day} тик {Tick}: событий {Events}, новостей {News}",
                        output.Snapshot.Day, _engine.State.TickOfDay,
                        output.Events.Count, output.News.Count);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (Exception e)
            {
                // Тик не должен убивать мир: логируем и живём дальше.
                _log.LogError(e, "Тик упал — продолжаем со следующего");
            }
        } while (await timer.WaitForNextTickAsync(ct));
    }
}
