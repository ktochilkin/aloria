using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.Engine;

/// <summary>
/// RNG-сэмплер стохастических событий. Здесь живут «опасные» решения, которые
/// нельзя доверять LLM: случился ли шок, какой охват, СЕРЬЁЗНОСТЬ (тяжёлый
/// хвост → редкие кризисы), знак и длительность. LLM получает готовый спек.
/// </summary>
public sealed class EventSampler
{
    private readonly Rng _rng;

    public EventSampler(Rng rng) => _rng = rng;

    /// <summary>Интенсивности приходов на ТИК по охватам (базовые, на день ~ ×TicksPerDay).</summary>
    public static (double Company, double Sector, double Macro) LambdaPerTick(
        Regime regime, bool crisis, int ticksPerDay)
    {
        // Целимся в ~3.5 корпоративных, ~0.8 секторных, ~0.3 макро событий в день.
        var mult = regime switch
        {
            Regime.Peak => 1.2,
            Regime.Recession => 1.5,
            _ => 1.0,
        };
        if (crisis) mult *= 1.8;
        return (3.5 * mult / ticksPerDay, 0.8 * mult / ticksPerDay, 0.3 * mult / ticksPerDay);
    }

    /// <summary>События этого тика (обычно 0..1, в кризис бывает больше).</summary>
    public List<EventSpec> SampleTick(WorldState w, WorldTuning tuning)
    {
        var (lc, ls, lm) = LambdaPerTick(w.Macro.Regime, w.Macro.Crisis, w.TicksPerDay);
        var k = tuning.EventRateMultiplier;
        var result = new List<EventSpec>();

        for (var i = 0; i < _rng.NextPoisson(lc * k); i++) result.Add(SampleCompany(w, tuning));
        for (var i = 0; i < _rng.NextPoisson(ls * k); i++) result.Add(SampleSector(w, tuning));
        for (var i = 0; i < _rng.NextPoisson(lm * k); i++) result.Add(SampleMacro(w, tuning));

        return result;
    }

    /// <summary>Серьёзность [0..1]: тело Beta(2,5), хвост Парето (шанс — из тюнинга).</summary>
    public double SampleSeverity(WorldTuning tuning)
    {
        if (_rng.Chance(tuning.TailChance))
        {
            // Хвост: 0.7..1.0, форма Парето (α=1.5)
            var tail = Math.Min(1.0, (_rng.NextPareto(1.5) - 1.0) / 4.0);
            return 0.7 + 0.3 * tail;
        }
        return Math.Min(1.0, _rng.NextBeta(2, 5));
    }

    private int SampleSign(WorldState w)
    {
        var pNegative = w.Macro.Regime switch
        {
            Regime.Expansion => 0.45,
            Regime.Peak => 0.55,
            Regime.Recession => 0.65,
            Regime.Recovery => 0.45,
            _ => 0.5,
        };
        if (w.Macro.Crisis) pNegative += 0.10;
        return _rng.Chance(pNegative) ? -1 : +1;
    }

    private (EventShape Shape, int Duration) SampleShape()
    {
        var u = _rng.NextDouble();
        if (u < 0.5) return (EventShape.Jump, 0);
        if (u < 0.8) return (EventShape.Drift, _rng.NextInt(4, 17));
        return (EventShape.Transient, _rng.NextInt(8, 33));
    }

    private EventSpec SampleCompany(WorldState w, WorldTuning tuning)
    {
        // Сектор — равновероятно; ЖЕРТВУ выбирает RNG (не LLM!): все числа и
        // адресаты экономики детерминированы от seed — LLM только рассказывает.
        var sector = _rng.Pick(Universe.Sectors);
        var pool = Universe.Issuers
            .Where(i => i.SectorSlug == sector.Slug && !w.Issuers[i.Symbol].Defaulted)
            .Select(i => i.Symbol)
            .ToArray();
        if (pool.Length == 0)
            pool = [_rng.Pick(Universe.Issuers).Symbol];
        var victim = _rng.Pick((IReadOnlyList<string>)pool);

        var (shape, dur) = SampleShape();
        return new EventSpec
        {
            Type = _rng.Chance(0.35) ? EventType.ProductNews : EventType.OperationsShock,
            Scope = EventScope.Company,
            Severity = SampleSeverity(tuning),
            Sign = SampleSign(w),
            Shape = shape,
            DurationTicks = dur,
            SectorSlug = sector.Slug,
            Symbol = victim,
            CandidateSymbols = [victim],
        };
    }

    private EventSpec SampleSector(WorldState w, WorldTuning tuning)
    {
        var sector = _rng.Pick(Universe.Sectors);
        var (shape, dur) = SampleShape();
        return new EventSpec
        {
            Type = EventType.SectorShock,
            Scope = EventScope.Sector,
            Severity = SampleSeverity(tuning),
            Sign = SampleSign(w),
            Shape = shape,
            DurationTicks = dur,
            SectorSlug = sector.Slug,
        };
    }

    private EventSpec SampleMacro(WorldState w, WorldTuning tuning)
    {
        var (shape, dur) = SampleShape();
        return new EventSpec
        {
            Type = EventType.MacroShock,
            Scope = EventScope.Macro,
            Severity = SampleSeverity(tuning),
            Sign = SampleSign(w),
            Shape = shape,
            DurationTicks = dur,
        };
    }
}
