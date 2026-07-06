using Aloria.Director.Core.Engine;
using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;
using Xunit;

namespace Aloria.Director.Core.Tests;

/// <summary>
/// Тесты «ДНК компаний»: скрытые moat/management, смены CEO и характер ЦБ.
/// </summary>
public class DnaTests
{
    private static async Task<(WorldEngine Engine, List<TickOutput> Outputs)> RunAsync(
        int seed, int days, int ticksPerDay = 24, WorldTuning? tuning = null)
    {
        var engine = new WorldEngine(new WorldConfig
        {
            Seed = seed,
            TicksPerDay = ticksPerDay,
            Tuning = tuning ?? new WorldTuning(),
        });
        var narrator = new TemplateNarrator(new Rng(seed ^ 0x5EED));
        var outputs = new List<TickOutput>();
        for (var t = 0; t < days * ticksPerDay; t++)
            outputs.Add(await engine.TickAsync(narrator));
        return (engine, outputs);
    }

    // ------------------------------------------------------ валидация вселенной

    [Fact]
    public void Universe_DnaValid()
    {
        // 22 компании с уникальными символами.
        Assert.Equal(22, Universe.Issuers.Count);
        Assert.Equal(22, Universe.Issuers.Select(i => i.Symbol).Distinct().Count());

        // Все сектора компаний существуют, realty появился.
        Assert.Contains(Universe.Sectors, s => s.Slug == "realty");
        foreach (var i in Universe.Issuers)
            Assert.Contains(Universe.Sectors, s => s.Slug == i.SectorSlug);

        // ДНК в диапазонах, CEO у всех — уникальные непустые имена.
        foreach (var i in Universe.Issuers)
        {
            Assert.InRange(i.Moat, 0.0, 1.0);
            Assert.InRange(i.MgmtQuality0, 0.0, 1.0);
            Assert.True(Enum.IsDefined(i.Stage), $"{i.Symbol}: stage не определён");
            Assert.False(string.IsNullOrWhiteSpace(i.CeoName0), $"{i.Symbol}: пустой CEO");
        }
        Assert.Equal(22, Universe.Issuers.Select(i => i.CeoName0).Distinct().Count());

        // Распределение стадий по контракту: 8 растущих, 3 защитных, 11 зрелых.
        Assert.Equal(8, Universe.Issuers.Count(i => i.Stage == CompanyStage.Growth));
        Assert.Equal(3, Universe.Issuers.Count(i => i.Stage == CompanyStage.Defensive));
        Assert.Equal(11, Universe.Issuers.Count(i => i.Stage == CompanyStage.Mature));

        // Облигации: 8 выпусков, эмитенты существуют (null = государство).
        Assert.Equal(8, Universe.Bonds.Count);
        Assert.Equal(8, Universe.Bonds.Select(b => b.Symbol).Distinct().Count());
        foreach (var b in Universe.Bonds.Where(b => b.IssuerSymbol is not null))
            Assert.Contains(Universe.Issuers, i => i.Symbol == b.IssuerSymbol);
        Assert.Contains(Universe.Bonds, b => b.Symbol == "ALZB1");
        Assert.Contains(Universe.Bonds, b => b.Symbol == "BLDB1");
    }

    // --------------------------------------------------------- персистентность

    [Fact]
    public async Task Persistence_Roundtrip_DnaFields()
    {
        var (engine, _) = await RunAsync(seed: 21, days: 5);

        // Двигаем ДНК-состояние руками, чтобы roundtrip был нетривиальным.
        var albk = engine.State.Issuers["ALBK"];
        albk.Management = 0.91;
        albk.CeoName = "Виктор Санников";
        albk.CeoSinceDay = 4;
        engine.State.CentralBank.GovernorName = "Регина Столпова";
        engine.State.CentralBank.Hawkishness = -0.55;
        engine.State.CentralBank.SinceDay = 3;

        var restored = new WorldEngine(
            new WorldConfig { Seed = 21, TicksPerDay = 24 }, engine.Persist());

        var r = restored.State.Issuers["ALBK"];
        Assert.Equal(0.91, r.Management, 9);
        Assert.Equal("Виктор Санников", r.CeoName);
        Assert.Equal(4, r.CeoSinceDay);
        Assert.Equal("Регина Столпова", restored.State.CentralBank.GovernorName);
        Assert.Equal(-0.55, restored.State.CentralBank.Hawkishness, 9);
        Assert.Equal(3, restored.State.CentralBank.SinceDay);

        // Остальные эмитенты тоже восстановились со своими живыми значениями.
        foreach (var sym in engine.State.Issuers.Keys)
        {
            Assert.Equal(
                engine.State.Issuers[sym].Management,
                restored.State.Issuers[sym].Management, 9);
            Assert.Equal(engine.State.Issuers[sym].CeoName, restored.State.Issuers[sym].CeoName);
        }
    }

    [Fact]
    public async Task Persistence_OldSnapshot_DefaultsFromSpec()
    {
        // Имитация СТАРОГО снимка: ДНК-полей нет (null/0), блока ЦБ нет.
        var (engine, _) = await RunAsync(seed: 22, days: 3);
        var dto = engine.Persist();
        var legacy = dto with
        {
            CentralBank = null,
            Issuers = dto.Issuers.ToDictionary(
                kv => kv.Key,
                kv => kv.Value with { Management = null, CeoName = null, CeoSinceDay = 0 }),
        };

        var restored = new WorldEngine(new WorldConfig { Seed = 22, TicksPerDay = 24 }, legacy);

        foreach (var issuer in restored.State.Issuers.Values)
        {
            Assert.Equal(issuer.Spec.MgmtQuality0, issuer.Management, 9);
            Assert.Equal(issuer.Spec.CeoName0, issuer.CeoName);
            Assert.Equal(0, issuer.CeoSinceDay);
        }
        Assert.Equal(Universe.InitialCbGovernor, restored.State.CentralBank.GovernorName);
        Assert.Equal(0.3, restored.State.CentralBank.Hawkishness, 9);
        Assert.Equal(0, restored.State.CentralBank.SinceDay);
    }

    // ------------------------------------------------------------ детерминизм

    [Fact]
    public async Task SameSeed_SameCeoHistoryAndCentralBank()
    {
        var (e1, o1) = await RunAsync(seed: 424, days: 70);
        var (e2, o2) = await RunAsync(seed: 424, days: 70);

        foreach (var sym in e1.State.Issuers.Keys)
        {
            Assert.Equal(e1.State.Issuers[sym].CeoName, e2.State.Issuers[sym].CeoName);
            Assert.Equal(e1.State.Issuers[sym].CeoSinceDay, e2.State.Issuers[sym].CeoSinceDay);
            Assert.Equal(e1.State.Issuers[sym].Management, e2.State.Issuers[sym].Management, 12);
        }
        Assert.Equal(e1.State.CentralBank.GovernorName, e2.State.CentralBank.GovernorName);
        Assert.Equal(e1.State.CentralBank.Hawkishness, e2.State.CentralBank.Hawkishness, 12);

        // Экономика при этом тоже совпадает (смены CEO не ломают поток костей).
        foreach (var sym in e1.State.Issuers.Keys)
            Assert.Equal(e1.State.Issuers[sym].Target, e2.State.Issuers[sym].Target, 9);

        // За 70 дней смены CEO реально происходят (hazard 22/150 в день) —
        // и в обоих прогонах их одинаковое число.
        int Changes(List<TickOutput> outputs) => outputs
            .SelectMany(o => o.Events)
            .Count(e => e.Spec is { Type: EventType.CeoChange, Scope: EventScope.Company });
        Assert.True(Changes(o1) > 0, "за 70 дней не случилось ни одной смены CEO");
        Assert.Equal(Changes(o1), Changes(o2));
    }

    // ------------------------------------------------------------- moat-эффект

    [Fact]
    public async Task Moat_NegativeCompanyImpact_ScaledByMoat()
    {
        // Статистика по симуляции: негативные корпоративные события в журнале.
        // Для каждого события |импакт| = sev² · 0.12 · (1.5 − Moat) → компания
        // с «рвом» .85 (BRED) при равной серьёзности теряет меньше, чем .25 (TRVL).
        var (_, outputs) = await RunAsync(seed: 31, days: 400);

        List<double> Ratios(string symbol) => outputs
            .SelectMany(o => o.Events)
            .Where(e => e.Spec.Scope == EventScope.Company
                        && e.Spec.Sign < 0
                        && e.Spec.Type is EventType.ProductNews or EventType.OperationsShock
                        && e.AppliedLogImpact.ContainsKey(symbol))
            .Select(e => Math.Abs(e.AppliedLogImpact[symbol])
                         / (e.Spec.Severity * e.Spec.Severity * 0.12))
            .ToList();

        var bred = Ratios("BRED");
        var trvl = Ratios("TRVL");
        Assert.True(bred.Count >= 5, $"мало негативных событий BRED: {bred.Count}");
        Assert.True(trvl.Count >= 5, $"мало негативных событий TRVL: {trvl.Count}");

        // Средний гаситель урона строго различим и равен (1.5 − Moat).
        Assert.True(bred.Average() < trvl.Average(),
            "устойчивая компания обязана терять меньше при равной серьёзности");
        Assert.Equal(1.5 - 0.85, bred.Average(), 6);
        Assert.Equal(1.5 - 0.25, trvl.Average(), 6);
    }

    [Fact]
    public async Task Moat_CrisisMacroShock_HighMoatLosesLess()
    {
        // Частые кризисы (ручка hazard), чтобы набрать статистику по
        // кризисным макро-шокам.
        var (_, outputs) = await RunAsync(seed: 32, days: 250,
            tuning: new WorldTuning { CrisisHazardPerDay = 0.10 });

        double Normalized(EventLogEntry e, string symbol)
        {
            var sector = Universe.SectorOfIssuer(Universe.Issuers.First(i => i.Symbol == symbol));
            return Math.Abs(e.AppliedLogImpact[symbol])
                   / (e.Spec.Severity * e.Spec.Severity * 0.04 * (0.5 + 0.5 * sector.BetaGrowth));
        }

        // Кризисные события распознаём по следу самого механизма: у BRED
        // нормированный импакт < 1 ⇔ моат-гаситель применён (мир был в кризисе).
        var negativeMacro = outputs
            .SelectMany(o => o.Events)
            .Where(e => e.Spec is { Scope: EventScope.Macro, Sign: < 0 }
                        && e.AppliedLogImpact.ContainsKey("BRED")
                        && e.AppliedLogImpact.ContainsKey("TRVL"))
            .ToList();
        var crisisHits = negativeMacro.Where(e => Normalized(e, "BRED") < 0.99).ToList();

        Assert.True(crisisHits.Count >= 3,
            $"мало кризисных макро-шоков для статистики: {crisisHits.Count}");
        foreach (var e in crisisHits)
        {
            // BRED (moat .85) гасит удар до ×0.65, TRVL (moat .25) получает ×1.25.
            Assert.Equal(1.5 - 0.85, Normalized(e, "BRED"), 6);
            Assert.Equal(1.5 - 0.25, Normalized(e, "TRVL"), 6);
        }
    }

    // ------------------------------------------------------ management-эффекты

    [Fact]
    public void Management_BiasesSignOfCompanyEvents()
    {
        // Длинная выборка сэмплера: доля позитивных продуктовых/операционных
        // событий следует P(+) = 0.35 + 0.4·Management.
        var world = new WorldState { TicksPerDay = 24 };
        foreach (var s in Universe.Sectors)
            world.Sectors[s.Slug] = new SectorState { Spec = s };
        foreach (var i in Universe.Issuers)
            world.Issuers[i.Symbol] = new IssuerState { Spec = i, Management = i.MgmtQuality0 };

        var sampler = new EventSampler(new Rng(7));
        var tuning = new WorldTuning();
        var positive = new Dictionary<string, int>();
        var total = new Dictionary<string, int>();
        for (var t = 0; t < 24 * 5000; t++)
        {
            foreach (var spec in sampler.SampleTick(world, tuning))
            {
                if (spec.Scope != EventScope.Company || spec.Symbol is null) continue;
                total[spec.Symbol] = total.GetValueOrDefault(spec.Symbol) + 1;
                if (spec.Sign > 0)
                    positive[spec.Symbol] = positive.GetValueOrDefault(spec.Symbol) + 1;
            }
        }

        double Share(string sym) => (double)positive.GetValueOrDefault(sym)
                                    / Math.Max(1, total.GetValueOrDefault(sym));

        Assert.True(total.GetValueOrDefault("DIGI") > 200, "мало событий DIGI");
        Assert.True(total.GetValueOrDefault("TRVL") > 200, "мало событий TRVL");

        // DIGI (mgmt .75, ожидание 0.65) заметно позитивнее TRVL (mgmt .40, 0.51).
        Assert.True(Share("DIGI") > Share("TRVL") + 0.05,
            $"DIGI {Share("DIGI"):0.###} vs TRVL {Share("TRVL"):0.###}");
        Assert.InRange(Share("DIGI"), 0.59, 0.71);
        Assert.InRange(Share("TRVL"), 0.45, 0.57);
    }

    [Fact]
    public async Task Management_DriftsEpsTrend()
    {
        // Сильная команда тянет EPS вверх, слабая — вниз (относительно базы).
        // Смотрим отношение EpsTrend/Base у лучшего (DIGI .75) и худшего
        // (TRVL .40) менеджмента на длинном горизонте без смен CEO невозможно
        // гарантировать — поэтому проверяем сам дневной механизм напрямую
        // через два коротких прогона одного мира недостаточно; берём статистику
        // по нескольким seed'ам.
        var digiUp = 0;
        var trvlDown = 0;
        foreach (var seed in new[] { 101, 202, 303, 404, 505 })
        {
            var (engine, _) = await RunAsync(seed, days: 30);
            var digi = engine.State.Issuers["DIGI"];
            var trvl = engine.State.Issuers["TRVL"];
            // Учитываем только миры, где CEO не менялись (чистый эффект).
            if (digi.CeoSinceDay == 0 && trvl.CeoSinceDay == 0)
            {
                var digiRel = digi.EpsTrend / digi.Spec.BaseEpsPerCycle;
                var trvlRel = trvl.EpsTrend / trvl.Spec.BaseEpsPerCycle;
                if (digiRel > trvlRel) digiUp++;
                else trvlDown++;
            }
        }
        Assert.True(digiUp > trvlDown,
            $"сильный менеджмент должен чаще растить EPS: {digiUp} vs {trvlDown}");
    }

    // ---------------------------------------------------------------- ЦБ

    [Fact]
    public void CentralBank_HawkishnessShiftsPolicy()
    {
        // При нейтральной макрокартине ястреб повышает, голубь снижает.
        var m = new MacroState { Inflation = 4.0, Growth = 2.0 };
        var hawk = RegimeMachine.PolicyDelta(m, +0.6);
        var neutral = RegimeMachine.PolicyDelta(m, 0);
        var dove = RegimeMachine.PolicyDelta(m, -0.6);

        Assert.Equal(0, neutral, 9);
        Assert.True(hawk > 0, $"ястреб должен повышать: {hawk}");
        Assert.True(dove < 0, $"голубь должен снижать: {dove}");
        Assert.True(hawk > dove);
    }

    [Fact]
    public async Task CeoChange_NewsCarryNameButNotNumbers()
    {
        var narrator = new TemplateNarrator(new Rng(5));
        var spec = new EventSpec
        {
            Type = EventType.CeoChange,
            Scope = EventScope.Company,
            Severity = 0.3,
            Sign = +1,
            Shape = EventShape.Jump,
            Symbol = "ALBK",
            Detail = "Виктор Санников",
        };
        var story = await narrator.NarrateAsync(new NewsDraft
        {
            Spec = spec,
            World = new WorldSnapshot
            {
                Day = 10, CycleDay = 1, Regime = Regime.Expansion, Crisis = false,
                KeyRate = 7.5, Inflation = 4.2, Growth = 2.0,
            },
        });

        // Имя назначенца в тексте есть, чисел «качества» — нет.
        Assert.Contains("Виктор Санников", story.Body);
        Assert.DoesNotContain("0.", story.Body);
        Assert.DoesNotContain("0,", story.Body);
    }

    [Fact]
    public async Task RateNews_ColoredByGovernorStyle()
    {
        var narrator = new TemplateNarrator(new Rng(5));
        var spec = new EventSpec
        {
            Type = EventType.RateDecision,
            Scope = EventScope.Macro,
            Severity = 0.5,
            Sign = -1,
            Shape = EventShape.Jump,
            Actual = 0.5,
            Expected = 0.5,
        };
        var story = await narrator.NarrateAsync(new NewsDraft
        {
            Spec = spec,
            World = new WorldSnapshot
            {
                Day = 5, CycleDay = 5, Regime = Regime.Peak, Crisis = false,
                KeyRate = 8.0, Inflation = 6.0, Growth = 3.0,
                CbGovernorName = "Элеонора Крейн", CbHawkishness = 0.6,
            },
        });

        // Ястребиный характер окрашивает новость (фамилия в тексте),
        // но само число ястребиности не публикуется.
        Assert.Contains("Крейн", story.Body);
        Assert.DoesNotContain("0.6", story.Body);
        Assert.DoesNotContain("0,6", story.Body);
    }
}
