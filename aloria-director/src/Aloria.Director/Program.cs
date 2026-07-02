using Aloria.Director;
using Aloria.Director.Adapters;
using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;

// ---------------------------------------------------------------------------
// Aloria Director — ИИ-режиссёр экономического мира Алории.
// Режимы:
//   dotnet run                          — боевой tick-loop + админ-API
//   dotnet run -- simulate --days 60    — быстрый прогон мира (трейс JSONL)
//   dotnet run -- seed                  — засев вселенной в Postgres terex
// ---------------------------------------------------------------------------

var builder = WebApplication.CreateBuilder(args);

var options = new DirectorOptions();
builder.Configuration.GetSection("Director").Bind(options);

// env-оверрайды ключевых настроек
if (Environment.GetEnvironmentVariable("DIRECTOR_TEREX_DB") is { Length: > 0 } dbEnv)
    options.TerexDb.ConnectionString = dbEnv;
if (Environment.GetEnvironmentVariable("DIRECTOR_SEED") is { Length: > 0 } seedEnv
    && int.TryParse(seedEnv, out var seedVal))
    options.Seed = seedVal;

// ---------------------------------------------------------------- simulate
if (args.Contains("simulate"))
{
    var days = ArgInt("--days", 30);
    var seed = ArgInt("--seed", options.Seed);
    var ticks = ArgInt("--ticks-per-day", options.TicksPerDay);
    var outPath = ArgString("--out", "sim-trace.jsonl");
    return await SimulationRunner.RunAsync(days, seed, ticks, outPath);
}

// -------------------------------------------------------------------- seed
if (args.Contains("seed"))
{
    if (options.TerexDb.ConnectionString is null)
    {
        Console.Error.WriteLine("Нет строки подключения: Director:TerexDb:ConnectionString или env DIRECTOR_TEREX_DB");
        return 1;
    }
    using var loggerFactory = LoggerFactory.Create(b => b.AddConsole());
    var db = new TerexDb(options.TerexDb.ConnectionString, loggerFactory.CreateLogger<TerexDb>());
    await db.EnsureDirectorSchemaAsync();
    var inserted = await db.SeedInstrumentsAsync();

    // Стартовые целевые цены — чтобы генератору было что котировать сразу.
    var engine = new WorldEngine(new WorldConfig { Seed = options.Seed, TicksPerDay = options.TicksPerDay });
    var first = await engine.TickAsync(new TemplateNarrator(new Rng(options.Seed ^ 0x5EED)));
    await db.UpsertTargetsAsync(first.Targets);
    await db.SaveWorldStateAsync(engine.Persist());

    Console.WriteLine($"Сид завершён: {inserted} новых инструментов, {first.Targets.Count} целевых цен.");
    return 0;
}

// --------------------------------------------------------------------- run
builder.WebHost.ConfigureKestrel(k => k.ListenAnyIP(options.Port));
builder.Services.ConfigureHttpJsonOptions(o =>
    o.SerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter()));
builder.Services.AddSingleton(options);
builder.Services.AddSingleton(options.Llm);
builder.Services.AddSingleton(options.AloriaApi);
builder.Services.AddSingleton(new Rng(options.Seed ^ 0x5EED));
builder.Services.AddSingleton<TemplateNarrator>();
builder.Services.AddHttpClient<OpenRouterNarrator>();
builder.Services.AddSingleton<INarrator>(sp => sp.GetRequiredService<OpenRouterNarrator>());
builder.Services.AddHttpClient<AloriaApiPublisher>();

if (options.TerexDb is { Enabled: true, ConnectionString: not null })
    builder.Services.AddSingleton(sp => new TerexDb(
        options.TerexDb.ConnectionString!, sp.GetRequiredService<ILogger<TerexDb>>()));

builder.Services.AddSingleton<DirectorWorker>(sp => new DirectorWorker(
    options,
    sp.GetRequiredService<INarrator>(),
    sp.GetRequiredService<ILogger<DirectorWorker>>(),
    sp.GetService<TerexDb>(),
    options.AloriaApi.Enabled ? sp.GetRequiredService<AloriaApiPublisher>() : null));
builder.Services.AddHostedService(sp => sp.GetRequiredService<DirectorWorker>());

var app = builder.Build();

app.MapGet("/", () => Results.Ok(new { name = "aloria-director", version = "0.1.0" }));
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/director/state", (DirectorWorker worker) =>
{
    var state = worker.CurrentState;
    if (state is null) return Results.NotFound(new { error = "мир ещё не инициализирован" });
    return Results.Ok(new
    {
        snapshot = worker.CurrentSnapshot,
        macro = state.Macro,
        issuers = state.Issuers.Values.Select(i => new
        {
            i.Spec.Symbol,
            i.Spec.Name,
            sector = i.Spec.SectorSlug,
            fair = Math.Round(Math.Exp(i.LogFair), 2),
            target = Math.Round(i.Target, 2),
            eps = Math.Round(i.EpsTrend, 2),
            distress = Math.Round(i.Distress, 2),
            i.Defaulted,
        }),
        bonds = state.Bonds.Values.Select(b => new
        {
            b.Spec.Symbol,
            b.Spec.Name,
            spread = Math.Round(b.Spread, 4),
            target = Math.Round(b.TargetClean, 2),
            accrued = Math.Round(b.Accrued, 3),
            daysToMaturity = b.DaysToMaturity,
            b.Defaulted,
            b.Matured,
        }),
        funds = state.Funds.Values.Select(f => new
        {
            f.Spec.Symbol, f.Spec.Name, target = Math.Round(f.Target, 2),
        }),
        calendarAhead = state.Calendar
            .Where(c => !c.Done && c.Day >= state.Day)
            .OrderBy(c => c.Day).ThenBy(c => c.TickOfDay)
            .Take(30),
    });
});

// Ручные рычаги мира: режим макроцикла и форс кризиса.
app.MapPost("/director/regime", async (RegimeInput input, DirectorWorker worker) =>
{
    if (!Enum.TryParse<Regime>(input.Regime, ignoreCase: true, out var regime))
        return Results.BadRequest(new { error = "regime: expansion|peak|recession|recovery" });
    var ok = await worker.ForceRegimeAsync(regime);
    return ok ? Results.Ok(new { forced = regime.ToString() }) : Results.Conflict();
});

// «Просчёт»: точное будущее живого мира (тот же поток костей), горизонт
// ограничен конфигом Director:Foresight (по умолчанию 30 дней, не дальше).
app.MapPost("/director/foresight", async (ForesightInput input, DirectorWorker worker) =>
{
    var result = await worker.ForesightAsync(input.Days);
    return result is null ? Results.NotFound() : Results.Ok(result);
});

app.MapPost("/director/crisis", async (DirectorWorker worker) =>
    await worker.ForceCrisisAsync()
        ? Results.Ok(new { crisis = true })
        : Results.Conflict(new { error = "кризис уже идёт или мир не инициализирован" }));

// Ручки тюнинга: посмотреть и покрутить на лету.
app.MapGet("/director/tuning", (DirectorWorker worker) =>
    worker.GetTuning() is { } t ? Results.Ok(t) : Results.NotFound());

app.MapPut("/director/tuning", async (WorldTuning input, DirectorWorker worker) =>
    await worker.SetTuningAsync(input) is { } t ? Results.Ok(t) : Results.NotFound());

// Ветка-симуляция от ТЕКУЩЕГО мира: {"days":60,"tuning":{...}} → сводка будущего.
// runs > 1 → ансамбль: N независимых веток, статистика вместо одной траектории.
app.MapPost("/director/simulate", async (SimulateInput input, DirectorWorker worker) =>
{
    var result = (input.Runs ?? 1) > 1
        ? await worker.SimulateEnsembleAsync(input.Days ?? 60, input.Runs!.Value, input.Tuning)
        : await worker.SimulateBranchAsync(input.Days ?? 60, input.Seed, input.Tuning);
    return result is null ? Results.NotFound() : Results.Ok(result);
});

app.Run();
return 0;

// --------------------------------------------------------------------------
int ArgInt(string name, int fallback)
{
    var idx = Array.IndexOf(args, name);
    return idx >= 0 && idx + 1 < args.Length && int.TryParse(args[idx + 1], out var v) ? v : fallback;
}

string ArgString(string name, string fallback)
{
    var idx = Array.IndexOf(args, name);
    return idx >= 0 && idx + 1 < args.Length ? args[idx + 1] : fallback;
}

internal sealed record RegimeInput(string Regime);

internal sealed record SimulateInput(int? Days, int? Seed, WorldTuning? Tuning, int? Runs);

internal sealed record ForesightInput(int? Days);
