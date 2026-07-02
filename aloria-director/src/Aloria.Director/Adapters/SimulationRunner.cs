using System.Text.Json;
using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;

namespace Aloria.Director.Adapters;

/// <summary>
/// Быстрый прогон мира на N дней без внешних систем: LLM — шаблоны, вывод —
/// JSONL-трейс (по записи на тик) + сводка. Для тестов баланса, дебага и
/// презентаций («вот 60 дней жизни мира на одном seed»).
/// </summary>
public static class SimulationRunner
{
    public static async Task<int> RunAsync(int days, int seed, int ticksPerDay, string outPath)
    {
        var config = new WorldConfig { Seed = seed, TicksPerDay = ticksPerDay };
        var engine = new WorldEngine(config);
        var narrator = new TemplateNarrator(new Rng(seed ^ 0x5EED));

        await using var trace = new StreamWriter(outPath);
        var newsTotal = 0;
        var eventsTotal = 0;
        var crisisTicks = 0;
        var regimeDays = new Dictionary<string, int>();
        var defaults = new List<string>();

        var totalTicks = days * ticksPerDay;
        for (var t = 0; t < totalTicks; t++)
        {
            var output = await engine.TickAsync(narrator);

            newsTotal += output.News.Count;
            eventsTotal += output.Events.Count;
            if (output.Snapshot.Crisis) crisisTicks++;
            if (output.Snapshot.Day <= days && engine.State.TickOfDay == 1)
            {
                var key = output.Snapshot.Regime.ToString();
                regimeDays[key] = regimeDays.GetValueOrDefault(key) + 1;
            }
            defaults.AddRange(output.Events
                .Where(e => e.Spec.Type == EventType.Default)
                .Select(e => e.Spec.Symbol ?? "?"));

            var record = new
            {
                day = output.Snapshot.Day,
                tick = output.Snapshot.Day * 10_000 + engine.State.TickOfDay,
                tickOfDay = engine.State.TickOfDay,
                regime = output.Snapshot.Regime.ToString(),
                crisis = output.Snapshot.Crisis,
                keyRate = output.Snapshot.KeyRate,
                inflation = output.Snapshot.Inflation,
                growth = output.Snapshot.Growth,
                targets = output.Targets.ToDictionary(x => x.Symbol, x => x.TargetPrice),
                news = output.News.Select(n => new
                {
                    n.Headline,
                    sentiment = n.Sentiment.ToString(),
                    type = n.Type.ToString(),
                    symbols = n.Symbols,
                }),
                events = output.Events.Select(e => new
                {
                    type = e.Spec.Type.ToString(),
                    scope = e.Spec.Scope.ToString(),
                    severity = Math.Round(e.Spec.Severity, 3),
                    sign = e.Spec.Sign,
                    impact = e.AppliedLogImpact,
                }),
            };
            await trace.WriteLineAsync(JsonSerializer.Serialize(record));
        }

        var summary = new
        {
            days,
            seed,
            ticksPerDay,
            newsTotal,
            eventsTotal,
            newsPerDay = Math.Round((double)newsTotal / days, 1),
            crisisShareOfTime = Math.Round((double)crisisTicks / totalTicks, 3),
            regimeDays,
            defaults,
            finalSnapshot = engine.Snapshot(),
            finalTargets = engine.State.Issuers.ToDictionary(
                kv => kv.Key, kv => Math.Round(kv.Value.Target, 2)),
        };

        var summaryPath = Path.ChangeExtension(outPath, ".summary.json");
        await File.WriteAllTextAsync(summaryPath,
            JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true }));

        Console.WriteLine($"Симуляция: {days} дней ({totalTicks} тиков), seed {seed}");
        Console.WriteLine($"Новостей: {newsTotal} (~{summary.newsPerDay}/день), событий: {eventsTotal}");
        Console.WriteLine($"Режимы (дней): {string.Join(", ", regimeDays.Select(kv => $"{kv.Key}={kv.Value}"))}");
        Console.WriteLine($"Кризис: {summary.crisisShareOfTime:P1} времени; дефолты: [{string.Join(", ", defaults)}]");
        Console.WriteLine($"Трейс: {outPath}");
        Console.WriteLine($"Сводка: {summaryPath}");
        return 0;
    }
}
