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

    /// <summary>«Зерно будущего» — из какого числа начат текущий поток костей.</summary>
    public int? CurrentFutureSeed => _engine?.FutureSeedLabel;

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

    /// <summary>
    /// «Перебросить будущее»: новый поток костей от текущего момента из
    /// заданного зерна (или случайного). Возвращает применённое зерно —
    /// его можно записать. Прошлое неизменно; прежний просчёт аннулируется.
    /// </summary>
    public async Task<int?> ReseedAsync(int? seed, CancellationToken ct = default)
    {
        if (_engine is null) return null;
        var applied = seed ?? Random.Shared.Next();
        await _engineLock.WaitAsync(ct);
        try
        {
            _engine.Reseed(applied);
            if (_db is not null)
                await _db.SaveWorldStateAsync(_engine.Persist(), ct);
        }
        finally
        {
            _engineLock.Release();
        }
        return applied;
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

    /// <summary>Дефолт в ветке: чей выпуск и через сколько дней от старта.</summary>
    private sealed record DefaultHit(string Symbol, int AfterDays);

    /// <summary>Итог одного прогона-ветки (для одиночного ответа, ансамбля и просчёта).</summary>
    private sealed record BranchStats(
        int Seed,
        int FromDay,
        double CrisisShare,
        int? FirstCrisisAfterDays,
        List<DefaultHit> Defaults,
        double NewsPerDay,
        Dictionary<string, int> RegimeDays,
        List<double> IndexDaily,
        List<string> RegimeDaily,
        List<bool> CrisisDaily,
        WorldSnapshot Final);

    private async Task<BranchStats> RunBranchAsync(
        WorldPersistDto snapshot, int days, int seed, WorldTuning? tuning, CancellationToken ct)
    {
        var branch = new WorldEngine(
            new WorldConfig { Seed = seed, TicksPerDay = _options.TicksPerDay },
            snapshot with { Tuning = (tuning ?? snapshot.Tuning ?? new WorldTuning()).Clamped() });
        var narrator = new TemplateNarrator(new Rng(seed ^ 0x5EED));

        var startDay = branch.State.Day;
        int? firstCrisisDay = null;
        var crisisTicks = 0;
        var newsTotal = 0;
        var regimeDays = new Dictionary<string, int>();
        var defaults = new List<DefaultHit>();
        var indexDaily = new List<double>();
        var regimeDaily = new List<string>();
        var crisisDaily = new List<bool>();

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
                .Select(e => new DefaultHit(e.Spec.Symbol ?? "?", output.Snapshot.Day - startDay)));
            if (branch.State.TickOfDay == 1)
            {
                var key = output.Snapshot.Regime.ToString();
                regimeDays[key] = regimeDays.GetValueOrDefault(key) + 1;
                indexDaily.Add(Math.Round(branch.State.Funds["ALIN"].Target, 2));
                regimeDaily.Add(key);
                crisisDaily.Add(output.Snapshot.Crisis);
            }
        }

        return new BranchStats(
            seed, startDay,
            Math.Round((double)crisisTicks / totalTicks, 3),
            firstCrisisDay - startDay,
            defaults,
            Math.Round((double)newsTotal / days, 1),
            regimeDays, indexDaily, regimeDaily, crisisDaily,
            branch.Snapshot());
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
        // Ветка-«возможное будущее»: свой поток костей (Rng из снимка отрезаем),
        // без явного seed каждый прогон — новый бросок.
        var s = await RunBranchAsync(
            snapshot with { Rng = null }, days, seed ?? Random.Shared.Next(), tuning, ct);

        return new
        {
            fromDay = s.FromDay,
            days,
            seed = s.Seed,
            newsPerDay = s.NewsPerDay,
            crisisShareOfTime = s.CrisisShare,
            firstCrisisAfterDays = s.FirstCrisisAfterDays,
            regimeDays = s.RegimeDays,
            defaults = s.Defaults.Select(d => d.Symbol).ToList(),
            indexDaily = s.IndexDaily,
            regimeDaily = s.RegimeDaily,
            crisisDaily = s.CrisisDaily,
            finalSnapshot = s.Final,
        };
    }

    /// <summary>
    /// «Просчёт» — ТОЧНОЕ будущее живого мира: ветка продолжает тот же поток
    /// костей (состояние RNG из снимка). Предсказание верно, пока никто не
    /// вмешивается (кнопки/тюнинг аннулируют его) и пока мир не зависит от
    /// внешних факторов (активность учеников и т.п. — когда появится обратная
    /// связь, просчёт уйдёт по своей природе). Горизонт ограничен конфигом.
    /// </summary>
    public async Task<object?> ForesightAsync(int? days, CancellationToken ct = default)
    {
        if (_engine is null) return null;

        WorldPersistDto snapshot;
        await _engineLock.WaitAsync(ct);
        try
        {
            snapshot = _engine.Persist(); // содержит состояние RNG — тот же поток
        }
        finally
        {
            _engineLock.Release();
        }

        var horizon = Math.Clamp(
            days ?? _options.Foresight.DefaultDays, 1, _options.Foresight.MaxDays);
        var s = await RunBranchAsync(snapshot, horizon, seed: 0 /* игнорируется: RNG из снимка */, null, ct);

        // Ключевые события будущего — списком, чтобы читалось без графика.
        var notable = new List<NotableEvent>();
        string? prevRegime = null;
        for (var i = 0; i < s.RegimeDaily.Count; i++)
        {
            if (prevRegime is not null && s.RegimeDaily[i] != prevRegime)
                notable.Add(new NotableEvent(i, $"режим → {s.RegimeDaily[i]}"));
            prevRegime = s.RegimeDaily[i];
            if (s.CrisisDaily[i] && (i == 0 || !s.CrisisDaily[i - 1]))
                notable.Add(new NotableEvent(i, "КРИЗИС"));
        }
        notable.AddRange(s.Defaults.Select(d => new NotableEvent(d.AfterDays, $"ДЕФОЛТ {d.Symbol}")));

        return new
        {
            exact = true,
            fromDay = s.FromDay,
            horizonDays = horizon,
            maxDays = _options.Foresight.MaxDays,
            crisisShareOfTime = s.CrisisShare,
            firstCrisisAfterDays = s.FirstCrisisAfterDays,
            defaults = s.Defaults,
            indexDaily = s.IndexDaily,
            regimeDaily = s.RegimeDaily,
            crisisDaily = s.CrisisDaily,
            notable = notable.OrderBy(n => n.AfterDays).ToList(),
            caveat = "Точно, пока никто не жмёт кнопки и не меняет ручки: любое вмешательство ветвит будущее.",
        };
    }

    private sealed record NotableEvent(int AfterDays, string What);

    /// <summary>
    /// Ансамбль: N независимых веток от одного и того же текущего мира.
    /// Один прогон — лотерея; ансамбль — статистика: средние, вероятности,
    /// коридор траекторий индекса (перцентили) и вероятность кризиса по дням.
    /// Ветки считаются параллельно по ядрам.
    /// </summary>
    public async Task<object?> SimulateEnsembleAsync(
        int days, int runs, WorldTuning? tuning, CancellationToken ct = default)
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
        runs = Math.Clamp(runs, 2, 64);

        var stats = new System.Collections.Concurrent.ConcurrentBag<BranchStats>();
        await Parallel.ForEachAsync(
            Enumerable.Range(0, runs),
            new ParallelOptions
            {
                MaxDegreeOfParallelism = Math.Max(2, Environment.ProcessorCount - 1),
                CancellationToken = ct,
            },
            async (_, token) =>
                stats.Add(await RunBranchAsync(
                    snapshot with { Rng = null }, days, Random.Shared.Next(), tuning, token)));

        var all = stats.ToList();
        var dayCount = all.Min(s => s.IndexDaily.Count);

        static double Percentile(List<double> sorted, double p)
        {
            var idx = (sorted.Count - 1) * p;
            var lo = (int)Math.Floor(idx);
            var hi = (int)Math.Ceiling(idx);
            return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
        }

        var p10 = new List<double>();
        var p50 = new List<double>();
        var p90 = new List<double>();
        var crisisProbDaily = new List<double>();
        for (var d = 0; d < dayCount; d++)
        {
            var vals = all.Select(s => s.IndexDaily[d]).OrderBy(v => v).ToList();
            p10.Add(Math.Round(Percentile(vals, 0.10), 2));
            p50.Add(Math.Round(Percentile(vals, 0.50), 2));
            p90.Add(Math.Round(Percentile(vals, 0.90), 2));
            crisisProbDaily.Add(Math.Round(all.Count(s => s.CrisisDaily[d]) / (double)runs, 2));
        }

        var firstDays = all
            .Where(s => s.FirstCrisisAfterDays.HasValue)
            .Select(s => (double)s.FirstCrisisAfterDays!.Value)
            .OrderBy(v => v)
            .ToList();
        var defaultProb = all
            .SelectMany(s => s.Defaults.Select(d => d.Symbol).Distinct())
            .GroupBy(sym => sym)
            .ToDictionary(g => g.Key, g => Math.Round(g.Count() / (double)runs, 2));

        return new
        {
            fromDay = all[0].FromDay,
            days,
            runs,
            crisisShare = new
            {
                mean = Math.Round(all.Average(s => s.CrisisShare), 3),
                min = all.Min(s => s.CrisisShare),
                max = all.Max(s => s.CrisisShare),
            },
            pAnyCrisis = Math.Round(all.Count(s => s.FirstCrisisAfterDays.HasValue) / (double)runs, 2),
            firstCrisisMedianDays = firstDays.Count > 0
                ? (double?)Math.Round(Percentile(firstDays, 0.5))
                : null,
            defaultProb,
            newsPerDay = Math.Round(all.Average(s => s.NewsPerDay), 1),
            indexP10 = p10,
            indexP50 = p50,
            indexP90 = p90,
            crisisProbDaily,
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

        // Справочник мира и полное состояние календаря публикуем на старте.
        if (_apiPublisher is not null)
        {
            await _apiPublisher.PublishReferenceAsync(ct);
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
