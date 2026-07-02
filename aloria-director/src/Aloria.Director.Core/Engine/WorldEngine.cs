using Aloria.Director.Core.Model;
using Aloria.Director.Core.News;

namespace Aloria.Director.Core.Engine;

/// <summary>Конфигурация мира.</summary>
public sealed record WorldConfig
{
    /// <summary>Seed мира: один seed — один воспроизводимый мир.</summary>
    public int Seed { get; init; } = 20260701;

    /// <summary>Тиков в мировом дне (96 = тик каждые 15 минут реального дня).</summary>
    public int TicksPerDay { get; init; } = 96;
}

/// <summary>
/// Оркестратор мира: один вызов <see cref="TickAsync"/> — один тик.
/// Порядок владения решениями: календарь/RNG-сэмплер → LLM-нарратор (текст,
/// выбор жертвы из пула) → формулы (сюрприз vs ожидания → импакт → целевые цены).
/// </summary>
public sealed class WorldEngine
{
    /// <summary>Усиление влияния макрофакторов на дневной дрейф справедливой стоимости.</summary>
    private const double MacroImpactK = 3.0;

    /// <summary>Скорость «гравитации» цели к справедливой стоимости (доля разрыва за день).</summary>
    private const double GravityPerDay = 0.35;

    /// <summary>Максимальный лог-импакт корпоративного события (severity=1).</summary>
    private const double CompanyImpactScale = 0.12;
    private const double SectorImpactScale = 0.06;
    private const double MacroImpactScale = 0.04;

    /// <summary>Импакт сюрприза отчётности: 0.05·tanh(z/2).</summary>
    private const double EarningsImpactScale = 0.05;

    /// <summary>Доля ожидаемого эффекта, закладываемая в цену заранее (pre-move).</summary>
    private const double PreMoveShare = 0.4;

    private readonly Rng _rng;
    private readonly EventSampler _sampler;
    private readonly Queue<string> _recentHeadlines = new();
    private int _lastPlannedCycleStart;

    public WorldState State { get; }

    public WorldEngine(WorldConfig config, WorldPersistDto? restore = null)
    {
        // При рестарте поток случайностей продолжается с нового зерна (seed⊕день):
        // прошлое мира — из снимка, будущее — новое, но воспроизводимое.
        _rng = new Rng(restore is null ? config.Seed : config.Seed ^ (restore.Day * 7919));
        _sampler = new EventSampler(_rng);
        State = new WorldState { TicksPerDay = config.TicksPerDay };

        foreach (var s in Universe.Sectors)
            State.Sectors[s.Slug] = new SectorState { Spec = s };

        foreach (var i in Universe.Issuers)
        {
            State.Issuers[i.Symbol] = new IssuerState
            {
                Spec = i,
                LogFair = Math.Log((double)i.StartPrice),
                Target = (double)i.StartPrice,
                EpsTrend = i.BaseEpsPerCycle,
            };
        }

        foreach (var b in Universe.Bonds)
        {
            var st = new BondState
            {
                Spec = b,
                Spread = BondMath.BaseSpread(b.Quality),
                DaysToMaturity = b.MaturityCycles * Universe.CycleDays,
            };
            st.TargetClean = BondMath.CleanPrice(
                b.CouponRatePerCycle, b.CouponEveryDays, st.DaysToMaturity,
                Yield(st));
            State.Bonds[b.Symbol] = st;
        }

        foreach (var f in Universe.Funds)
        {
            var st = new FundState { Spec = f, Target = (double)f.StartPrice };
            st.Divisor = RawBasket(f) / (double)f.StartPrice;
            State.Funds[f.Symbol] = st;
        }

        if (restore is null)
        {
            State.Calendar.AddRange(CalendarPlanner.PlanCycle(State, 1, _rng));
            _lastPlannedCycleStart = 1;
        }
        else
        {
            WorldPersistence.Apply(State, restore);
            _lastPlannedCycleStart = restore.LastPlannedCycleStart;
        }
    }

    /// <summary>Снимок мира для сохранения (JSON → director.world_state).</summary>
    public WorldPersistDto Persist() => WorldPersistence.ToDto(State, _lastPlannedCycleStart);

    private double Yield(BondState b) => State.Macro.KeyRate / 100.0 + b.Spread;

    // ------------------------------------------------------------------ tick

    public async Task<TickOutput> TickAsync(INarrator narrator, CancellationToken ct = default)
    {
        var output = new TickOutput { Snapshot = Snapshot() };

        if (State.TickOfDay == 0)
            await DailyOpenAsync(output, ct);

        await PublishExpectationsAsync(narrator, output, ct);
        await ExecuteScheduledAsync(narrator, output, ct);
        await ApplyStochasticAsync(narrator, output, ct);

        UpdateTargetsTick();
        UpdateFunds();
        EmitTargets(output);

        // Сдвиг часов в конец тика.
        State.TickOfDay++;
        if (State.TickOfDay >= State.TicksPerDay)
        {
            State.TickOfDay = 0;
            State.Day++;
        }

        return output;
    }

    // ------------------------------------------------------------- daily open

    private async Task DailyOpenAsync(TickOutput output, CancellationToken ct)
    {
        var m = State.Macro;

        // Новый цикл — планируем календарь вперёд.
        if (State.CycleDay == 1 && _lastPlannedCycleStart != State.Day)
        {
            var events = CalendarPlanner.PlanCycle(State, State.Day, _rng);
            State.Calendar.AddRange(events);
            output.NewCalendarEvents.AddRange(events);
            _lastPlannedCycleStart = State.Day;
        }

        var regimeChanged = RegimeMachine.DailyStep(m, _rng);
        output.MacroChanged = true;

        if (regimeChanged)
            output.News.Add(RegimeChangeNews(m));

        // Перегрев может лопнуть: редкий, но регулярный источник кризисов
        // (примерно каждый пятый-шестой пик).
        if (m is { Regime: Regime.Peak, Crisis: false } && _rng.Chance(0.04))
        {
            EnterCrisis();
            output.News.Add(new WorldNews
            {
                Headline = "Перегрев лопнул: рынки Алории в штопоре",
                Body = "Накопленные дисбалансы прорвались: аппетит к риску испарился, продажи идут широким фронтом. Волатильность резко выросла — в такие моменты особенно важно понимать, чем владеешь и зачем.",
                Sentiment = Sentiment.Negative,
                Type = EventType.MacroShock,
                Scope = EventScope.Macro,
                Day = State.Day,
                TickOfDay = State.TickOfDay,
                Urgency = 3,
            });
        }

        var volMult = RegimeMachine.VolMultiplier(m.Regime, m.Crisis);

        // Общие дневные шумы: рыночный (в кризис корреляции → 1) и секторные.
        var marketNoise = m.Crisis ? _rng.NextGaussian(0, 0.02 * volMult) : 0.0;
        var sectorNoise = Universe.Sectors.ToDictionary(
            s => s.Slug,
            s => _rng.NextGaussian(0, s.SigmaDaily * volMult));

        foreach (var issuer in State.Issuers.Values)
        {
            if (issuer.Defaulted) continue;
            var spec = issuer.Spec;
            var sector = Universe.SectorOf(spec.SectorSlug);

            // Потоковые макрофакторы (рост/инфляция) дрейфуют цену каждый день;
            // ставка влияет ТОЛЬКО в момент решений (ApplyRateImpact) — иначе
            // уровень ставки капитализировался бы в цену бесконечно.
            var drift = 0.01 * MacroImpactK / Universe.CycleDays * (
                sector.BetaGrowth * (m.Growth - 2.0)
                + sector.BetaInflation * (m.Inflation - 4.0));

            // Накопление прибыли: за цикл цена прирастает на earnings yield,
            // дивидендная часть вычитается на отсечке → в цене остаётся
            // нераспределённая прибыль. Без этого дивиденды съедали бы цену.
            var price = Math.Exp(issuer.LogFair);
            var earningsAccrual = Math.Log(
                1 + issuer.EpsTrend / Universe.CycleDays / Math.Max(1e-6, price));

            issuer.LogFair += drift
                + earningsAccrual
                + marketNoise
                + sectorNoise[spec.SectorSlug]
                + _rng.NextGaussian(0, spec.SigmaDaily * volMult);

            // Дистресс: OU к базе (плечо × режим + кризис), события добавляют сверху.
            var baseDistress =
                spec.Leverage * (m.Regime == Regime.Recession ? 0.55 : 0.15)
                + (m.Crisis ? 0.35 : 0.0);
            issuer.Distress = Math.Clamp(
                issuer.Distress + 0.3 * (baseDistress - issuer.Distress), 0, 1);
        }

        // Облигации: день к погашению, НКД, спред, переоценка.
        foreach (var bond in State.Bonds.Values)
        {
            if (bond.Matured) continue;
            bond.DaysToMaturity = Math.Max(0, bond.DaysToMaturity - 1);

            var issuerDistress = bond.Spec.IssuerSymbol is { } sym
                ? State.Issuers[sym].Distress
                : 0.0;

            if (!bond.Defaulted)
            {
                var target = BondMath.BaseSpread(bond.Spec.Quality)
                             + (m.Regime == Regime.Recession ? 0.02 : 0.0)
                             + (m.Crisis ? 0.025 : 0.0)
                             + issuerDistress * 0.10;
                bond.Spread += 0.35 * (target - bond.Spread);
                bond.TargetClean = BondMath.CleanPrice(
                    bond.Spec.CouponRatePerCycle, bond.Spec.CouponEveryDays,
                    bond.DaysToMaturity, Yield(bond),
                    DaysSinceCoupon(bond));
            }

            bond.Accrued = BondMath.Accrued(
                bond.Spec.CouponRatePerCycle, bond.Spec.CouponEveryDays, DaysSinceCoupon(bond));
        }
    }

    private int DaysSinceCoupon(BondState b) => State.Day % b.Spec.CouponEveryDays;

    private WorldNews RegimeChangeNews(MacroState m)
    {
        var (headline, body, sentiment) = m.Regime switch
        {
            Regime.Expansion => ("Экономика Алории выходит на подъём",
                "Индикаторы указывают на устойчивый рост: спрос и занятость восстанавливаются. Исторически в такой фазе циклические секторы чувствуют себя лучше защитных — но многое уже может быть в ценах.",
                Sentiment.Positive),
            Regime.Peak => ("Экономика Алории перегревается",
                "Рост на пределе возможностей: инфляция ускоряется, дефицит кадров, ставки склонны расти. В такой фазе рынок особенно чувствителен к плохим новостям.",
                Sentiment.Neutral),
            Regime.Recession => ("Алория входит в рецессию",
                "Деловая активность сжимается, прибыли компаний под давлением. Защитные секторы обычно устойчивее, закредитованные компании — уязвимее.",
                Sentiment.Negative),
            Regime.Recovery => ("Экономика Алории нащупала дно",
                "Спад замедлился, появляются признаки восстановления. Аппетит к риску возвращается постепенно и неравномерно.",
                Sentiment.Positive),
            _ => ("Смена фазы экономического цикла", "Экономика Алории переходит в новую фазу.", Sentiment.Neutral),
        };
        return new WorldNews
        {
            Headline = headline,
            Body = body,
            Sentiment = sentiment,
            Type = EventType.MacroShock,
            Scope = EventScope.Macro,
            Day = State.Day,
            TickOfDay = State.TickOfDay,
            Urgency = 3,
        };
    }

    // ----------------------------------------------------------- expectations

    /// <summary>За день до отчёта/заседания ЦБ публикуется консенсус и происходит pre-move.</summary>
    private async Task PublishExpectationsAsync(INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var due = State.Calendar.Where(e =>
            !e.Done && !e.ExpectationPublished
            && e.Type is EventType.Earnings or EventType.RateDecision
            && e.Day == State.Day + 1
            && e.TickOfDay == State.TickOfDay);

        foreach (var evt in due)
        {
            evt.ExpectationPublished = true;
            double expected, sigma;

            if (evt.Type == EventType.Earnings)
            {
                var issuer = State.Issuers[evt.Symbol!];
                var regimeAdj = RegimeEarningsAdj();
                expected = issuer.EpsTrend * (1 + regimeAdj) * (1 + _rng.NextGaussian(0, 0.06));
                sigma = Math.Max(0.02, Math.Abs(expected) * 0.08);

                // Pre-move: рынок частично закладывает ожидание.
                var zE = (expected - issuer.EpsTrend) / sigma;
                issuer.LogFair += PreMoveShare * EarningsImpactScale * Math.Tanh(zE / 2);
            }
            else
            {
                expected = RegimeMachine.PolicyDelta(State.Macro);
                sigma = 0.25;
                ApplyRateImpact(expected * PreMoveShare);
            }

            State.Expectations[evt.Id] = new Expectation
            {
                EventId = evt.Id,
                Expected = expected,
                Sigma = sigma,
            };

            var spec = new EventSpec
            {
                Type = EventType.ExpectationNote,
                Scope = evt.Type == EventType.RateDecision ? EventScope.Macro : EventScope.Company,
                Severity = 0.1,
                Sign = 0,
                Shape = EventShape.Jump,
                Symbol = evt.Symbol,
                Expected = expected,
            };
            var story = await narrator.NarrateAsync(Draft(spec), ct);
            AddNews(output, story, spec, urgency: 1);
        }
    }

    private double RegimeEarningsAdj() => State.Macro.Regime switch
    {
        Regime.Expansion => +0.06,
        Regime.Peak => +0.02,
        Regime.Recession => -0.18,
        Regime.Recovery => -0.02,
        _ => 0,
    } + (State.Macro.Crisis ? -0.10 : 0);

    // ------------------------------------------------------ scheduled events

    private async Task ExecuteScheduledAsync(INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var due = State.Calendar
            .Where(e => !e.Done && e.Day == State.Day && e.TickOfDay == State.TickOfDay)
            .ToList();

        foreach (var evt in due)
        {
            evt.Done = true;
            switch (evt.Type)
            {
                case EventType.Earnings: await EarningsAsync(evt, narrator, output, ct); break;
                case EventType.DividendDecision: await DividendDecisionAsync(evt, narrator, output, ct); break;
                case EventType.DividendCutoff: await DividendCutoffAsync(evt, narrator, output, ct); break;
                case EventType.DividendPayout: await SimpleBondlikeNewsAsync(evt, EventType.DividendPayout, narrator, output, ct); break;
                case EventType.Coupon: await CouponAsync(evt, narrator, output, ct); break;
                case EventType.Maturity: await MaturityAsync(evt, narrator, output, ct); break;
                case EventType.RateDecision: await RateDecisionAsync(evt, narrator, output, ct); break;
            }
        }
    }

    private async Task EarningsAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var issuer = State.Issuers[evt.Symbol!];
        var exp = State.Expectations.GetValueOrDefault(evt.Id);
        var regimeAdj = RegimeEarningsAdj();
        var actual = issuer.EpsTrend * (1 + regimeAdj) * (1 + _rng.NextGaussian(0, 0.10));
        var expected = exp?.Expected ?? issuer.EpsTrend * (1 + regimeAdj);
        var sigma = exp?.Sigma ?? Math.Max(0.02, Math.Abs(expected) * 0.08);

        var z = Math.Clamp((actual - expected) / sigma, -4, 4);
        var impact = EarningsImpactScale * Math.Tanh(z / 2);
        issuer.LogFair += impact;
        issuer.EpsTrend = 0.7 * issuer.EpsTrend + 0.3 * Math.Max(0.1, actual);
        if (z < -1.5) issuer.Distress = Math.Clamp(issuer.Distress + 0.10, 0, 1);

        var spec = new EventSpec
        {
            Type = EventType.Earnings,
            Scope = EventScope.Company,
            Severity = Math.Min(1, Math.Abs(z) / 3),
            Sign = Math.Sign(z),
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
            SurpriseZ = z,
            Actual = Math.Round(actual, 2),
            Expected = Math.Round(expected, 2),
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 2);
        LogEvent(output, spec, new() { [evt.Symbol!] = impact }, story.Headline);
    }

    private async Task DividendDecisionAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var issuer = State.Issuers[evt.Symbol!];
        var expectedDiv = issuer.Spec.PayoutRatio * issuer.EpsTrend;
        var cut = issuer.Distress > 0.6 && _rng.Chance(0.6);
        var actualDiv = cut
            ? expectedDiv * (_rng.Chance(0.5) ? 0.0 : 0.5)
            : Math.Max(0, expectedDiv * (1 + _rng.NextGaussian(0, 0.10)));

        var sigma = Math.Max(0.01, expectedDiv * 0.12);
        var z = Math.Clamp((actualDiv - expectedDiv) / sigma, -4, 4);
        var impact = cut ? -0.035 : 0.02 * Math.Tanh(z / 2);
        issuer.LogFair += impact;
        issuer.PendingDividend = actualDiv;

        var spec = new EventSpec
        {
            Type = EventType.DividendDecision,
            Scope = EventScope.Company,
            Severity = cut ? 0.5 : 0.2,
            Sign = cut ? -1 : Math.Sign(z),
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
            Actual = Math.Round(actualDiv, 2),
            Expected = Math.Round(expectedDiv, 2),
            SurpriseZ = z,
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: cut ? 3 : 2);
        LogEvent(output, spec, new() { [evt.Symbol!] = impact }, story.Headline);
    }

    private async Task DividendCutoffAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var issuer = State.Issuers[evt.Symbol!];
        var div = issuer.PendingDividend;
        if (div <= 0) return;

        // Механика отсечки: цена «очищается» от дивиденда — учебный момент.
        var price = Math.Exp(issuer.LogFair);
        var impact = -Math.Log(1 + div / Math.Max(1e-6, price));
        issuer.LogFair += impact;

        var spec = new EventSpec
        {
            Type = EventType.DividendCutoff,
            Scope = EventScope.Company,
            Severity = 0.15,
            Sign = 0,
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
            Actual = Math.Round(div, 2),
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 1);
        LogEvent(output, spec, new() { [evt.Symbol!] = impact }, story.Headline);
    }

    private async Task SimpleBondlikeNewsAsync(
        CalendarEvent evt, EventType type, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var spec = new EventSpec
        {
            Type = type,
            Scope = EventScope.Company,
            Severity = 0.1,
            Sign = 0,
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 1);
    }

    private async Task CouponAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var bond = State.Bonds[evt.Symbol!];
        if (bond.Matured || bond.Defaulted) return;

        var issuer = bond.Spec.IssuerSymbol is { } sym ? State.Issuers[sym] : null;

        // Дефолт: хвостовой исход у дистресснутого эмитента в момент купона.
        var pDefault = issuer is null ? 0 : Math.Max(0, (issuer.Distress - 0.75) * 1.2);
        if (issuer is not null && _rng.Chance(pDefault))
        {
            bond.Defaulted = true;
            issuer.Distress = 1; // компания живёт (акция торгуется), но в глубоком дистрессе
            bond.TargetClean = BondMath.RecoveryPrice(_rng);
            var equityImpact = -0.25;
            issuer.LogFair += equityImpact;

            var dSpec = new EventSpec
            {
                Type = EventType.Default,
                Scope = EventScope.Company,
                Severity = 1,
                Sign = -1,
                Shape = EventShape.Jump,
                Symbol = evt.Symbol,
            };
            var dStory = await narrator.NarrateAsync(Draft(dSpec), ct);
            AddNews(output, dStory, dSpec, urgency: 3);
            LogEvent(output, dSpec, new()
            {
                [evt.Symbol!] = Math.Log(bond.TargetClean / 100.0),
                [bond.Spec.IssuerSymbol!] = equityImpact,
            }, dStory.Headline);
            return;
        }

        bond.Accrued = 0;
        var spec = new EventSpec
        {
            Type = EventType.Coupon,
            Scope = EventScope.Company,
            Severity = 0.05,
            Sign = 0,
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 1);
    }

    private async Task MaturityAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var bond = State.Bonds[evt.Symbol!];
        if (bond.Matured) return;

        var spec = new EventSpec
        {
            Type = EventType.Maturity,
            Scope = EventScope.Company,
            Severity = 0.1,
            Sign = 0,
            Shape = EventShape.Jump,
            Symbol = evt.Symbol,
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 2);

        var issuerDefaulted = bond.Spec.IssuerSymbol is { } sym && State.Issuers[sym].Distress >= 0.95;
        if (issuerDefaulted || bond.Defaulted)
        {
            // Дистресс-эмитент новую серию не размещает — выпуск уходит с рынка.
            bond.Matured = true;
            bond.TargetClean = 100;
            return;
        }

        // Роллирование: взамен погашенного размещается новая серия под тем же
        // тикером — рынок облигаций не пересыхает, календарь пополняется.
        bond.DaysToMaturity = bond.Spec.MaturityCycles * Universe.CycleDays;
        bond.Spread = BondMath.BaseSpread(bond.Spec.Quality);
        bond.Accrued = 0;
        bond.TargetClean = BondMath.CleanPrice(
            bond.Spec.CouponRatePerCycle, bond.Spec.CouponEveryDays,
            bond.DaysToMaturity, Yield(bond));

        output.News.Add(new WorldNews
        {
            Headline = $"Размещена новая серия {bond.Spec.Name}",
            Body = "Взамен погашенного выпуска эмитент разместил новую серию с той же купонной ставкой. Держатели могут реинвестировать номинал — это обычный цикл долгового рынка.",
            Sentiment = Sentiment.Neutral,
            Type = EventType.Coupon,
            Scope = EventScope.Company,
            Symbols = [bond.Spec.Symbol],
            Day = State.Day,
            TickOfDay = State.TickOfDay,
            Urgency = 1,
        });
    }

    private async Task RateDecisionAsync(CalendarEvent evt, INarrator narrator, TickOutput output, CancellationToken ct)
    {
        var exp = State.Expectations.GetValueOrDefault(evt.Id);
        var expected = exp?.Expected ?? RegimeMachine.PolicyDelta(State.Macro);

        var surprise = _rng.NextDouble() switch
        {
            < 0.15 => -0.25,
            > 0.85 => +0.25,
            _ => 0.0,
        };
        var actual = Math.Clamp(expected + surprise, -2, 2);
        State.Macro.KeyRate = Math.Clamp(State.Macro.KeyRate + actual, 0.5, 25);
        output.MacroChanged = true;

        // На решении рынок доигрывает: сюрприз целиком + оставшаяся часть ожидания.
        ApplyRateImpact(actual - expected * PreMoveShare);

        var spec = new EventSpec
        {
            Type = EventType.RateDecision,
            Scope = EventScope.Macro,
            Severity = Math.Min(1, Math.Abs(actual) / 2 + Math.Abs(surprise)),
            Sign = -Math.Sign(actual),
            Shape = EventShape.Jump,
            Actual = actual,
            Expected = expected,
            SurpriseZ = surprise / 0.25,
        };
        var story = await narrator.NarrateAsync(Draft(spec), ct);
        AddNews(output, story, spec, urgency: 3);
        LogEvent(output, spec, new() { ["*rate*"] = actual }, story.Headline);
    }

    /// <summary>Кризисный оверлей: волатильность ×2, корреляции → 1, режим — рецессия.</summary>
    private void EnterCrisis()
    {
        State.Macro.Crisis = true;
        if (State.Macro.Regime != Regime.Recession)
        {
            State.Macro.Regime = Regime.Recession;
            State.Macro.RegimeAgeDays = 0;
            State.Macro.RegimePlannedDays = RegimeMachine.SampleDuration(Regime.Recession, _rng);
        }
    }

    /// <summary>Влияние изменения ставки на справедливые стоимости акций.</summary>
    private void ApplyRateImpact(double deltaPp)
    {
        if (Math.Abs(deltaPp) < 1e-9) return;
        foreach (var issuer in State.Issuers.Values)
        {
            if (issuer.Defaulted) continue;
            var sector = Universe.SectorOf(issuer.Spec.SectorSlug);
            var betaREff = sector.BetaRate - 0.6 * issuer.Spec.Leverage;
            issuer.LogFair += 0.01 * MacroImpactK * betaREff * deltaPp;
        }
    }

    // ----------------------------------------------------- stochastic events

    private async Task ApplyStochasticAsync(INarrator narrator, TickOutput output, CancellationToken ct)
    {
        foreach (var spec in _sampler.SampleTick(State))
        {
            var story = await narrator.NarrateAsync(Draft(spec), ct);
            var applied = new Dictionary<string, double>();

            switch (spec.Scope)
            {
                case EventScope.Company:
                {
                    var symbol = spec.Symbol
                                 ?? story.ChosenSymbol
                                 ?? (spec.CandidateSymbols.Count > 0
                                     ? _rng.Pick(spec.CandidateSymbols)
                                     : Universe.Issuers[0].Symbol);
                    if (!State.Issuers.TryGetValue(symbol, out var issuer)) break;

                    var magnitude = spec.Sign * spec.Severity * spec.Severity * CompanyImpactScale;
                    ApplyShaped(issuer, magnitude, spec);
                    applied[symbol] = magnitude;
                    if (spec.Sign < 0)
                        issuer.Distress = Math.Clamp(issuer.Distress + spec.Severity * 0.25, 0, 1);
                    break;
                }
                case EventScope.Sector:
                {
                    var magnitude = spec.Sign * spec.Severity * spec.Severity * SectorImpactScale;
                    foreach (var issuer in State.Issuers.Values.Where(i =>
                                 i.Spec.SectorSlug == spec.SectorSlug && !i.Defaulted))
                    {
                        ApplyShaped(issuer, magnitude, spec);
                        applied[issuer.Spec.Symbol] = magnitude;
                    }
                    State.Sectors[spec.SectorSlug!].Shock += magnitude;
                    break;
                }
                case EventScope.Macro:
                {
                    State.Macro.Growth += spec.Sign * spec.Severity * 2.0;
                    State.Macro.RiskAppetite = Math.Clamp(
                        State.Macro.RiskAppetite + spec.Sign * spec.Severity * 0.3, -1, 1);
                    output.MacroChanged = true;

                    foreach (var issuer in State.Issuers.Values.Where(i => !i.Defaulted))
                    {
                        var sector = Universe.SectorOf(issuer.Spec.SectorSlug);
                        var magnitude = spec.Sign * spec.Severity * spec.Severity * MacroImpactScale
                                        * (0.5 + 0.5 * sector.BetaGrowth);
                        ApplyShaped(issuer, magnitude, spec);
                        applied[issuer.Spec.Symbol] = magnitude;
                    }

                    // Хвостовой негативный макрошок = кризис.
                    if (spec.Sign < 0 && spec.Severity >= 0.85 && !State.Macro.Crisis)
                        EnterCrisis();
                    break;
                }
            }

            AddNews(output, story, spec,
                urgency: spec.Severity > 0.7 ? 3 : spec.Severity > 0.35 ? 2 : 1,
                overrideSymbol: applied.Count == 1 ? applied.Keys.First() : null);
            LogEvent(output, spec, applied, story.Headline);
        }
    }

    /// <summary>Применяет импакт по форме: скачок / тление / временный шок.</summary>
    private static void ApplyShaped(IssuerState issuer, double magnitude, EventSpec spec)
    {
        switch (spec.Shape)
        {
            case EventShape.Jump:
                issuer.LogFair += magnitude;
                break;
            case EventShape.Drift:
                issuer.Smoulder.Add((spec.DurationTicks, magnitude / spec.DurationTicks));
                break;
            case EventShape.Transient:
                // Скачок сейчас + плавный возврат: суммарно эффект уходит в ноль.
                issuer.LogFair += magnitude;
                issuer.Smoulder.Add((spec.DurationTicks, -magnitude / spec.DurationTicks));
                break;
        }
    }

    // ------------------------------------------------------------- targets

    private void UpdateTargetsTick()
    {
        var m = State.Macro;
        var volMult = RegimeMachine.VolMultiplier(m.Regime, m.Crisis);
        var tpd = State.TicksPerDay;

        foreach (var issuer in State.Issuers.Values)
        {
            // Тлеющие шоки.
            for (var i = issuer.Smoulder.Count - 1; i >= 0; i--)
            {
                var (ticksLeft, perTick) = issuer.Smoulder[i];
                issuer.LogFair += perTick;
                if (--ticksLeft <= 0) issuer.Smoulder.RemoveAt(i);
                else issuer.Smoulder[i] = (ticksLeft, perTick);
            }

            var sigma = issuer.Spec.SigmaDaily * volMult;
            var logT = Math.Log(Math.Max(1e-9, issuer.Target));
            logT += GravityPerDay / tpd * (issuer.LogFair - logT)
                    + 0.7 * sigma / Math.Sqrt(tpd) * _rng.NextGaussian();
            issuer.Target = Math.Exp(logT);
        }

        foreach (var bond in State.Bonds.Values.Where(b => !b.Matured))
        {
            if (bond.Defaulted) continue;
            bond.TargetClean = Math.Max(1,
                bond.TargetClean + _rng.NextGaussian(0, 0.015 * volMult));
        }
    }

    private double RawBasket(FundSpec fund)
    {
        if (fund.IsBondFund)
        {
            var live = State.Bonds.Values.Where(b => !b.Matured).ToList();
            // Пустая корзина (все выпуски погашены/дефолтнулись) — пай у номинала.
            return live.Count == 0 ? 100.0 : live.Average(b => b.TargetClean + b.Accrued);
        }
        return State.Issuers.Values.Sum(i => i.Spec.SharesMln * i.Target);
    }

    private void UpdateFunds()
    {
        foreach (var fund in State.Funds.Values)
        {
            var nav = RawBasket(fund.Spec) / fund.Divisor;
            // Небольшой шум трекинга: арбитраж держит пай у NAV.
            fund.Target = nav * (1 + _rng.NextGaussian(0, 0.0005));
        }
    }

    private void EmitTargets(TickOutput output)
    {
        foreach (var issuer in State.Issuers.Values)
        {
            output.Targets.Add(new PriceTarget
            {
                Symbol = issuer.Spec.Symbol,
                TargetPrice = Quantize((decimal)issuer.Target, issuer.Spec.PriceStep),
                SigmaDaily = Math.Clamp(
                    issuer.Spec.SigmaDaily * RegimeMachine.VolMultiplier(State.Macro.Regime, State.Macro.Crisis),
                    0.004, 0.08),
                Active = !issuer.Defaulted,
            });
        }

        foreach (var bond in State.Bonds.Values)
        {
            output.Targets.Add(new PriceTarget
            {
                Symbol = bond.Spec.Symbol,
                TargetPrice = Quantize((decimal)bond.TargetClean, Universe.BondPriceStep),
                SigmaDaily = bond.Defaulted ? 0.03 : 0.004,
                Active = !bond.Matured,
            });
        }

        foreach (var fund in State.Funds.Values)
        {
            output.Targets.Add(new PriceTarget
            {
                Symbol = fund.Spec.Symbol,
                TargetPrice = Quantize((decimal)fund.Target, 0.01m),
                SigmaDaily = fund.Spec.IsBondFund ? 0.004 : 0.010,
                Active = true,
            });
        }
    }

    private static decimal Quantize(decimal value, decimal step)
        => step <= 0 ? value : Math.Max(step, Math.Round(value / step, MidpointRounding.AwayFromZero) * step);

    // --------------------------------------------------------------- helpers

    private NewsDraft Draft(EventSpec spec) => new()
    {
        Spec = spec,
        World = Snapshot(),
        RecentHeadlines = _recentHeadlines.ToArray(),
    };

    public WorldSnapshot Snapshot() => new()
    {
        Day = State.Day,
        CycleDay = State.CycleDay,
        Regime = State.Macro.Regime,
        Crisis = State.Macro.Crisis,
        KeyRate = Math.Round(State.Macro.KeyRate, 2),
        Inflation = Math.Round(State.Macro.Inflation, 2),
        Growth = Math.Round(State.Macro.Growth, 2),
    };

    private void AddNews(
        TickOutput output, NewsStory story, EventSpec spec, int urgency, string? overrideSymbol = null)
    {
        var symbol = overrideSymbol ?? story.ChosenSymbol ?? spec.Symbol;
        var sectorSlug = spec.SectorSlug
                         ?? (symbol is not null
                             ? Universe.Issuers.FirstOrDefault(i => i.Symbol == symbol)?.SectorSlug
                             : null);

        output.News.Add(new WorldNews
        {
            Headline = story.Headline,
            Body = story.Body,
            Sentiment = story.Sentiment,
            Type = spec.Type,
            Scope = spec.Scope,
            Symbols = symbol is null ? [] : [symbol],
            SectorSlug = sectorSlug,
            Day = State.Day,
            TickOfDay = State.TickOfDay,
            Urgency = urgency,
        });

        _recentHeadlines.Enqueue(story.Headline);
        while (_recentHeadlines.Count > 12) _recentHeadlines.Dequeue();
    }

    private void LogEvent(
        TickOutput output, EventSpec spec, Dictionary<string, double> applied, string headline)
        => output.Events.Add(new EventLogEntry
        {
            Day = State.Day,
            TickOfDay = State.TickOfDay,
            Spec = spec,
            AppliedLogImpact = applied,
            Headline = headline,
        });
}
