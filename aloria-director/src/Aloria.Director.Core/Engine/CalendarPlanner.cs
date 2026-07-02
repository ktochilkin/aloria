using Aloria.Director.Core.Model;

namespace Aloria.Director.Core.Engine;

/// <summary>
/// Планировщик календаря цикла: отчётности, дивидендные цепочки
/// (решение → отсечка → выплата), купоны, погашения, заседание ЦБ.
/// Ритм, который ученик может предвосхищать.
/// </summary>
public static class CalendarPlanner
{
    /// <summary>День заседания ЦБ внутри цикла.</summary>
    public const int RateDecisionCycleDay = 5;

    /// <summary>Планирует события цикла, начинающегося с мирового дня <paramref name="cycleStartDay"/>.</summary>
    public static List<CalendarEvent> PlanCycle(WorldState w, int cycleStartDay, Rng rng)
    {
        var events = new List<CalendarEvent>();
        var tpd = w.TicksPerDay;

        // Заседание ЦБ — фиксированный день цикла, середина дня.
        events.Add(new CalendarEvent
        {
            Id = $"cb-{cycleStartDay + RateDecisionCycleDay - 1}",
            Type = EventType.RateDecision,
            Day = cycleStartDay + RateDecisionCycleDay - 1,
            TickOfDay = tpd / 2,
        });

        // Отчётности: каждой компании один день в цикле (дни 2..9), плюс
        // дивидендная цепочка для платящих: решение (тот же день, позже),
        // отсечка (+1 день), выплата (+2 дня).
        foreach (var issuer in Universe.Issuers)
        {
            var day = cycleStartDay + rng.NextInt(1, Universe.CycleDays - 1); // дни 2..9 цикла
            var tick = rng.NextInt(tpd / 6, tpd / 2); // «утро»

            events.Add(new CalendarEvent
            {
                Id = $"earn-{issuer.Symbol}-{day}",
                Type = EventType.Earnings,
                Day = day,
                TickOfDay = tick,
                Symbol = issuer.Symbol,
            });

            if (issuer.PayoutRatio > 0)
            {
                events.Add(new CalendarEvent
                {
                    Id = $"divd-{issuer.Symbol}-{day}",
                    Type = EventType.DividendDecision,
                    Day = day,
                    TickOfDay = Math.Min(tick + tpd / 4, tpd - 1),
                    Symbol = issuer.Symbol,
                });
                events.Add(new CalendarEvent
                {
                    Id = $"divc-{issuer.Symbol}-{day + 1}",
                    Type = EventType.DividendCutoff,
                    Day = day + 1,
                    TickOfDay = tpd / 3,
                    Symbol = issuer.Symbol,
                });
                events.Add(new CalendarEvent
                {
                    Id = $"divp-{issuer.Symbol}-{day + 2}",
                    Type = EventType.DividendPayout,
                    Day = day + 2,
                    TickOfDay = tpd / 3,
                    Symbol = issuer.Symbol,
                });
            }
        }

        // Купоны и погашения облигаций.
        foreach (var bond in Universe.Bonds)
        {
            var state = w.Bonds[bond.Symbol];
            if (state.Defaulted || state.Matured) continue;

            for (var d = 0; d < Universe.CycleDays; d++)
            {
                var worldDay = cycleStartDay + d;
                var daysLeftAtThatDay = state.DaysToMaturity - (worldDay - w.Day);
                if (daysLeftAtThatDay <= 0)
                {
                    events.Add(new CalendarEvent
                    {
                        Id = $"mat-{bond.Symbol}-{worldDay}",
                        Type = EventType.Maturity,
                        Day = worldDay,
                        TickOfDay = tpd / 2,
                        Symbol = bond.Symbol,
                    });
                    break;
                }

                if (worldDay % bond.CouponEveryDays == 0)
                {
                    events.Add(new CalendarEvent
                    {
                        Id = $"cpn-{bond.Symbol}-{worldDay}",
                        Type = EventType.Coupon,
                        Day = worldDay,
                        TickOfDay = tpd / 4,
                        Symbol = bond.Symbol,
                    });
                }
            }
        }

        return events;
    }
}
