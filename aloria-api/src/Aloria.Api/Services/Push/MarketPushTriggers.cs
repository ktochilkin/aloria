using Aloria.Api.Data;
using Aloria.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services.Push;

/// <summary>
/// Триггеры пушей экономического мира. Живут на стороне aloria-api: режиссёр
/// просто пишет новости/макросостояние, а решение «кому и что пушить»
/// принимается здесь при ингесте (см. MarketEndpoints).
/// </summary>
public static class MarketPushTriggers
{
    /// <summary>
    /// Пуш по свежей новости: срочное в мире (worldAlerts) или новость
    /// компании (companyNews). Заголовок — из новости (до 60 символов),
    /// текст — первые ~100 символов содержимого.
    /// </summary>
    public static Task NotifyNewsAsync(
        PushDispatcher dispatcher, NewsItem news, CancellationToken ct)
    {
        var alert = IsWorldAlert(news);
        return dispatcher.DispatchToCategoryAsync(
            alert ? PushCategory.WorldAlerts : PushCategory.CompanyNews,
            alert ? NotificationType.WorldAlert : NotificationType.CompanyNews,
            new Dictionary<string, string>
            {
                ["title"] = Truncate(news.Headline, 60),
                ["body"] = Truncate(news.Content, 100),
            },
            ct);
    }

    /// <summary>
    /// Пуши по изменению макросостояния: смена фазы цикла, старт нового цикла
    /// (cycleEvents) и дайджест календаря при открытии нового мирового дня
    /// (calendarDigest). Старое состояние передаётся снаружи — эндпоинт читает
    /// его до перезаписи.
    /// </summary>
    public static async Task NotifyMacroChangedAsync(
        AloriaDbContext db,
        PushDispatcher dispatcher,
        MacroState state,
        string? oldRegime,
        int? oldCycleDay,
        CancellationToken ct)
    {
        // Смена фазы. Первый PUT (старого состояния не было) не пушим —
        // это заведение мира, а не событие для пользователя.
        if (oldRegime != null
            && !string.Equals(oldRegime, state.Regime, StringComparison.OrdinalIgnoreCase))
        {
            await dispatcher.DispatchToCategoryAsync(
                PushCategory.CycleEvents, NotificationType.CycleEvent,
                new Dictionary<string, string>
                {
                    ["title"] = "Экономика Алории",
                    ["body"] = $"Фаза цикла сменилась: {RegimeRu(oldRegime)} → {RegimeRu(state.Regime)}.",
                },
                ct);
        }

        // Старт нового цикла: cycleDay стал 1, а был не 1.
        if (oldCycleDay is { } prevForCycle && prevForCycle != 1 && state.CycleDay == 1)
        {
            await dispatcher.DispatchToCategoryAsync(
                PushCategory.CycleEvents, NotificationType.CycleEvent,
                new Dictionary<string, string>
                {
                    ["title"] = "Экономика Алории",
                    ["body"] = $"Начался новый экономический цикл — впереди {state.CycleLength} дней отчётов, купонов и решений ЦБ.",
                },
                ct);
        }

        // Новый мировой день (cycleDay изменился) — дайджест календаря дня.
        if (oldCycleDay is { } prevDay && prevDay != state.CycleDay)
        {
            var digest = await BuildCalendarDigestAsync(db, state, ct);
            if (digest != null)
            {
                await dispatcher.DispatchToCategoryAsync(
                    PushCategory.CalendarDigest, NotificationType.CalendarDigest,
                    new Dictionary<string, string>
                    {
                        ["title"] = "Календарь дня",
                        ["body"] = digest,
                    },
                    ct);
            }
        }
    }

    /// <summary>
    /// Срочное ли это событие мира. Контрактные типы {crisis, rate, default,
    /// cbGovernor} сопоставлены фактическому словарю режиссёра
    /// (AloriaApiPublisher.MapType): «rate» — решение ЦБ по ставке, «default» —
    /// дефолт эмитента, «management» со scope=macro — смена главы ЦБ; кризисы
    /// и смены фазы приходят как «macro» с urgency=3, поэтому порог срочности —
    /// 3 (2 у режиссёра — обычная новость по умолчанию).
    /// </summary>
    private static bool IsWorldAlert(NewsItem n) =>
        n.EventType is "rate" or "default"
        || (n.EventType == "management" && n.Scope == "macro")
        || n.Urgency >= 3;

    /// <summary>
    /// Текст дайджеста событий сегодняшнего дня («Сегодня в Алории: …») или
    /// null, если событий нет. В MacroState нет абсолютного номера дня, а
    /// календарь хранит абсолютные дни мира; режиссёр планирует календарь
    /// только на текущий цикл, поэтому «сегодня» — максимальный день календаря,
    /// совпадающий с cycleDay по модулю длины цикла.
    /// </summary>
    private static async Task<string?> BuildCalendarDigestAsync(
        AloriaDbContext db, MacroState state, CancellationToken ct)
    {
        var len = state.CycleLength > 0 ? state.CycleLength : 10;
        var days = await db.CycleCalendar.Select(x => x.Day).Distinct().ToListAsync(ct);
        var today = days
            .Where(d => d >= 1 && (d - 1) % len + 1 == state.CycleDay)
            .DefaultIfEmpty(0)
            .Max();
        if (today == 0) return null;

        var events = await db.CycleCalendar
            .Where(x => x.Day == today)
            .OrderBy(x => x.TickOfDay)
            .ToListAsync(ct);
        if (events.Count == 0) return null;

        // Имена инструментов — из справочника мира, фолбэк на тикер.
        var symbols = events
            .Select(e => e.Symbol)
            .Where(s => !string.IsNullOrEmpty(s))
            .Select(s => s!)
            .Distinct()
            .ToList();
        var companyNames = await db.ReferenceCompanies
            .Where(c => symbols.Contains(c.Symbol))
            .ToDictionaryAsync(c => c.Symbol, c => c.Name, ct);
        var bondNames = await db.ReferenceBonds
            .Where(b => symbols.Contains(b.Symbol))
            .ToDictionaryAsync(b => b.Symbol, b => b.Name, ct);

        string NameOf(string? symbol) => symbol == null
            ? string.Empty
            : companyNames.GetValueOrDefault(symbol) ?? bondNames.GetValueOrDefault(symbol) ?? symbol;

        var parts = new List<string>();
        var seen = new HashSet<string>();
        foreach (var e in events)
        {
            // Дивидендная цепочка (решение/отсечка/выплата) приходит одним
            // типом «dividend» — дубли по (тип, тикер) схлопывает seen.
            var part = e.Type switch
            {
                "rate" => "заседание ЦБ по ставке",
                "earnings" => $"отчёт {NameOf(e.Symbol)}",
                "dividend" => $"дивиденды {NameOf(e.Symbol)}",
                "coupon" => $"купон {NameOf(e.Symbol)}",
                "maturity" => $"погашение {NameOf(e.Symbol)}",
                _ => null,
            };
            if (part == null || !seen.Add(part)) continue;
            parts.Add(part);
        }
        if (parts.Count == 0) return null;

        const int maxParts = 5;
        var tail = parts.Count > maxParts ? $" и ещё {parts.Count - maxParts}" : string.Empty;
        return $"Сегодня в Алории: {string.Join(", ", parts.Take(maxParts))}{tail}.";
    }

    /// <summary>Русское название фазы цикла для текста пуша.</summary>
    private static string RegimeRu(string regime) => regime.ToLowerInvariant() switch
    {
        "expansion" => "Рост",
        "peak" => "Перегрев",
        "recession" => "Спад",
        "recovery" => "Восстановление",
        _ => regime,
    };

    private static string Truncate(string s, int max) =>
        s.Length <= max ? s : s[..(max - 1)].TrimEnd() + "…";
}
