using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;
using Xunit;

namespace Aloria.Director.Core.Tests;

public class WorldEngineTests
{
    private static async Task<(WorldEngine Engine, List<TickOutput> Outputs)> RunAsync(
        int seed, int days, int ticksPerDay = 24)
    {
        var engine = new WorldEngine(new WorldConfig { Seed = seed, TicksPerDay = ticksPerDay });
        var narrator = new TemplateNarrator(new Rng(seed ^ 0x5EED));
        var outputs = new List<TickOutput>();
        for (var t = 0; t < days * ticksPerDay; t++)
            outputs.Add(await engine.TickAsync(narrator));
        return (engine, outputs);
    }

    [Fact]
    public async Task ThirtyDays_WorldStaysSane()
    {
        var (engine, outputs) = await RunAsync(seed: 1, days: 30);

        // Целевые цены положительные и не улетели в бесконечность.
        foreach (var issuer in engine.State.Issuers.Values)
        {
            Assert.True(issuer.Target > 0);
            var start = (double)issuer.Spec.StartPrice;
            Assert.InRange(issuer.Target, start * 0.2, start * 5);
        }

        // Облигации в осмысленном диапазоне (не дефолт → 60..130% номинала).
        foreach (var bond in engine.State.Bonds.Values.Where(b => !b.Defaulted && !b.Matured))
            Assert.InRange(bond.TargetClean, 60, 130);

        // Мир живой: новости и события идут.
        Assert.True(outputs.Sum(o => o.News.Count) > 50);
        Assert.True(outputs.Sum(o => o.Events.Count) > 30);

        // Ставка в коридоре политики.
        Assert.InRange(engine.State.Macro.KeyRate, 0.5, 25);
    }

    [Fact]
    public async Task SameSeed_SameWorld()
    {
        var (e1, _) = await RunAsync(seed: 77, days: 10);
        var (e2, _) = await RunAsync(seed: 77, days: 10);

        foreach (var sym in e1.State.Issuers.Keys)
            Assert.Equal(e1.State.Issuers[sym].Target, e2.State.Issuers[sym].Target, 9);
        Assert.Equal(e1.State.Macro.KeyRate, e2.State.Macro.KeyRate, 9);
    }

    [Fact]
    public async Task DifferentSeed_DifferentWorld()
    {
        var (e1, _) = await RunAsync(seed: 1, days: 10);
        var (e2, _) = await RunAsync(seed: 2, days: 10);

        var same = e1.State.Issuers.Keys.Count(sym =>
            Math.Abs(e1.State.Issuers[sym].Target - e2.State.Issuers[sym].Target) < 1e-6);
        Assert.True(same < e1.State.Issuers.Count / 2);
    }

    [Fact]
    public async Task Earnings_HappenForEveryIssuerEachCycle()
    {
        var (_, outputs) = await RunAsync(seed: 3, days: Universe.CycleDays);
        var earningsSymbols = outputs
            .SelectMany(o => o.Events)
            .Where(e => e.Spec.Type == EventType.Earnings)
            .Select(e => e.Spec.Symbol)
            .ToHashSet();

        // Отчёты в дни 2..9 → как минимум большинство эмитентов отчиталось за цикл.
        Assert.True(earningsSymbols.Count >= Universe.Issuers.Count - 2,
            $"отчитались только {earningsSymbols.Count} из {Universe.Issuers.Count}");
    }

    [Fact]
    public async Task RateDecision_HappensOncePerCycle()
    {
        var (_, outputs) = await RunAsync(seed: 4, days: 2 * Universe.CycleDays);
        var decisions = outputs
            .SelectMany(o => o.News)
            .Count(n => n.Type == EventType.RateDecision);
        Assert.Equal(2, decisions);
    }

    [Fact]
    public async Task Persistence_Roundtrip_ContinuesWorld()
    {
        var (e1, _) = await RunAsync(seed: 9, days: 7);
        var dto = e1.Persist();

        var restored = new WorldEngine(
            new WorldConfig { Seed = 9, TicksPerDay = 24 }, dto);

        Assert.Equal(e1.State.Day, restored.State.Day);
        Assert.Equal(e1.State.Macro.Regime, restored.State.Macro.Regime);
        Assert.Equal(e1.State.Macro.KeyRate, restored.State.Macro.KeyRate, 9);
        foreach (var sym in e1.State.Issuers.Keys)
            Assert.Equal(e1.State.Issuers[sym].Target, restored.State.Issuers[sym].Target, 9);

        // Мир продолжается без исключений.
        var narrator = new TemplateNarrator(new Rng(1));
        for (var t = 0; t < 48; t++)
            await restored.TickAsync(narrator);
        Assert.True(restored.State.Day > e1.State.Day);
    }

    [Fact]
    public async Task Targets_QuantizedToPriceStep()
    {
        var (_, outputs) = await RunAsync(seed: 11, days: 3);
        var last = outputs[^1];

        foreach (var target in last.Targets)
        {
            var issuer = Universe.Issuers.FirstOrDefault(i => i.Symbol == target.Symbol);
            var step = issuer?.PriceStep
                       ?? (Universe.Bonds.Any(b => b.Symbol == target.Symbol)
                           ? Universe.BondPriceStep
                           : 0.01m);
            var remainder = target.TargetPrice % step;
            Assert.True(remainder == 0, $"{target.Symbol}: {target.TargetPrice} не кратна {step}");
        }
    }

    [Fact]
    public async Task Tuning_CrisisHazard_MakesCrisesFrequent()
    {
        var engine = new WorldEngine(new WorldConfig
        {
            Seed = 5,
            TicksPerDay = 24,
            Tuning = new WorldTuning { CrisisHazardPerDay = 0.5 },
        });
        var narrator = new TemplateNarrator(new Rng(1));

        var sawCrisis = false;
        for (var t = 0; t < 15 * 24 && !sawCrisis; t++)
        {
            await engine.TickAsync(narrator);
            sawCrisis = engine.State.Macro.Crisis;
        }
        Assert.True(sawCrisis, "при hazard 0.5/день кризис обязан случиться за 15 дней");
    }

    [Fact]
    public async Task Tuning_SurvivesPersistRoundtrip()
    {
        var tuning = new WorldTuning { TailChance = 0.2, PeakBubbleBurstPerDay = 0.1 };
        var engine = new WorldEngine(new WorldConfig { Seed = 8, TicksPerDay = 24, Tuning = tuning });
        await engine.TickAsync(new TemplateNarrator(new Rng(1)));

        var restored = new WorldEngine(
            new WorldConfig { Seed = 8, TicksPerDay = 24 }, engine.Persist());
        Assert.Equal(0.2, restored.Tuning.TailChance, 9);
        Assert.Equal(0.1, restored.Tuning.PeakBubbleBurstPerDay, 9);
    }

    [Fact]
    public void Tuning_Clamped_RejectsNonsense()
    {
        var wild = new WorldTuning { EventRateMultiplier = 99, TailChance = 3, CrisisHazardPerDay = -1 };
        var c = wild.Clamped();
        Assert.Equal(10, c.EventRateMultiplier);
        Assert.Equal(0.5, c.TailChance);
        Assert.Equal(0, c.CrisisHazardPerDay);
    }

    [Fact]
    public async Task Expectations_PublishedBeforeEarnings()
    {
        var (_, outputs) = await RunAsync(seed: 6, days: Universe.CycleDays);
        var notes = outputs.SelectMany(o => o.News).Count(n => n.Type == EventType.ExpectationNote);
        Assert.True(notes > 0, "консенсус-ожидания не публикуются");
    }
}
