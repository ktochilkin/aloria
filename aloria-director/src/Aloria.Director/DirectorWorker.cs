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

    /// <summary>Текущие ручки тюнинга мира.</summary>
    public WorldTuning? GetTuning() => _engine?.Tuning;

    /// <summary>Обновить тюнинг на лету (клампится к разумным диапазонам, переживает рестарт).</summary>
    public async Task<WorldTuning?> SetTuningAsync(WorldTuning tuning, CancellationToken ct = default)
    {
        if (_engine is null) return null;
        await _engineLock.WaitAsync(ct);
        try
        {
            _engine.Tuning = tuning.Clamped();
            if (_db is not null)
                await _db.SaveWorldStateAsync(_engine.Persist(), ct);
            return _engine.Tuning;
        }
        finally
        {
            _engineLock.Release();
        }
    }

    /// <summary>Ручной форс кризиса: прямо сейчас, без ожидания хвоста распределения.</summary>
    public async Task<bool> ForceCrisisAsync(CancellationToken ct = default)
    {
        if (_engine is null) return false;
        await _engineLock.WaitAsync(ct);
        try
        {
            if (!_engine.ForceCrisis()) return false;
        }
        finally
        {
            _engineLock.Release();
        }

        if (_apiPublisher is not null)
        {
            await _apiPublisher.PublishNewsAsync([new WorldNews
            {
                Headline = "Рынки Алории накрыла волна распродаж",
                Body = "Аппетит к риску испарился, продажи идут широким фронтом, волатильность резко выросла. В такие моменты особенно важно понимать, чем владеешь и зачем.",
                Sentiment = Sentiment.Negative,
                Type = EventType.MacroShock,
                Scope = EventScope.Macro,
                Day = _engine.State.Day,
                TickOfDay = _engine.State.TickOfDay,
                Urgency = 3,
            }], ct);
            await _apiPublisher.PublishMacroAsync(_engine.Snapshot(), ct);
        }
        return true;
    }

    /// <summary>
    /// Ветка-симуляция: клонирует ТЕКУЩИЙ мир и быстро прогоняет N дней вперёд
    /// (шаблонный нарратор, без БД/HTTP). Возвращает сводку — «одно возможное
    /// будущее» при заданных ручках. ~2 сек на 120 дней.
    /// </summary>
    public async Task<object?> SimulateBranchAsync(
        int days, int? seed, WorldTuning? tuning, CancellationToken ct = default)
    {
        if (_engine is null) return null;

        WorldPersistDto snapshot;
        await _engineLock.WaitAsync(ct);
        try
        {
            snapshot = _engine.Persist();
        }
        finally
        {
            _engineLock.Release();
        }

        days = Math.Clamp(days, 1, 365);
        var branchSeed = seed ?? unchecked(_options.Seed ^ (snapshot.Day * 92821 + snapshot.TickOfDay * 31));
        var branch = new WorldEngine(
            new WorldConfig { Seed = branchSeed, TicksPerDay = _options.TicksPerDay },
            snapshot with { Tuning = (tuning ?? snapshot.Tuning ?? new WorldTuning()).Clamped() });
        var narrator = new TemplateNarrator(new Rng(branchSeed ^ 0x5EED));

        var startDay = branch.State.Day;
        int? firstCrisisDay = null;
        var crisisTicks = 0;
        var newsTotal = 0;
        var regimeDays = new Dictionary<string, int>();
        var defaults = new List<string>();
        var indexDaily = new List<double>();

        var totalTicks = days * _options.TicksPerDay;
        for (var t = 0; t < totalTicks; t++)
        {
            ct.ThrowIfCancellationRequested();
            var output = await branch.TickAsync(narrator, ct);
            newsTotal += output.News.Count;
            if (output.Snapshot.Crisis)
            {
                crisisTicks++;
                firstCrisisDay ??= output.Snapshot.Day;
            }
            defaults.AddRange(output.Events
                .Where(e => e.Spec.Type == EventType.Default)
                .Select(e => e.Spec.Symbol ?? "?"));
            if (branch.State.TickOfDay == 1)
            {
                var key = output.Snapshot.Regime.ToString();
                regimeDays[key] = regimeDays.GetValueOrDefault(key) + 1;
                indexDaily.Add(Math.Round(branch.State.Funds["ALIN"].Target, 2));
            }
        }

        return new
        {
            fromDay = startDay,
            days,
            seed = branchSeed,
            tuning = branch.Tuning,
            newsPerDay = Math.Round((double)newsTotal / days, 1),
            crisisShareOfTime = Math.Round((double)crisisTicks / totalTicks, 3),
            firstCrisisDay,
            firstCrisisAfterDays = firstCrisisDay - startDay,
            regimeDays,
            defaults,
            indexDaily,
            finalSnapshot = branch.Snapshot(),
        };
    }

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
