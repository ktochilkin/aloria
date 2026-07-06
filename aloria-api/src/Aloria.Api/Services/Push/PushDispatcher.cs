using Aloria.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services.Push;

/// <summary>
/// Единая точка отправки пушей: по типу собирает сообщение, берёт активные
/// токены, шлёт через <see cref="IPushSender"/> и гасит мёртвые токены.
/// Адресация — одному пользователю (<see cref="DispatchAsync"/>), всем
/// (<see cref="DispatchToAllAsync"/>) или по категории с учётом настроек
/// устройства и троттлинга (<see cref="DispatchToCategoryAsync"/>).
/// Учитываются пуш-категории устройств: у каждого типа есть категория
/// (<see cref="MapCategory"/>), и устройство с выключенным тумблером её не получит.
/// </summary>
public class PushDispatcher(
    AloriaDbContext db,
    IPushSender sender,
    PushThrottle throttle,
    ILogger<PushDispatcher> log)
{
    /// Отправка одному пользователю — на все его активные устройства
    /// (с учётом маски категорий, если у типа есть категория).
    public async Task<DispatchOutcome> DispatchAsync(
        Guid userId,
        NotificationType type,
        IReadOnlyDictionary<string, string>? args = null,
        CancellationToken ct = default)
    {
        var mask = (int)(MapCategory(type) ?? PushCategory.None);
        var tokens = await db.DeviceTokens
            .Where(d => d.UserId == userId && !d.Disabled
                && (mask == 0 || (d.Categories & mask) != 0))
            .Select(d => d.Token)
            .ToListAsync(ct);
        return await SendAsync(tokens, type, args, ct);
    }

    /// Рассылка всем — на все активные устройства всех пользователей
    /// (с учётом маски категорий, если у типа есть категория).
    public async Task<DispatchOutcome> DispatchToAllAsync(
        NotificationType type,
        IReadOnlyDictionary<string, string>? args = null,
        CancellationToken ct = default)
    {
        var mask = (int)(MapCategory(type) ?? PushCategory.None);
        var tokens = await db.DeviceTokens
            .Where(d => !d.Disabled && (mask == 0 || (d.Categories & mask) != 0))
            .Select(d => d.Token)
            .ToListAsync(ct);
        return await SendAsync(tokens, type, args, ct);
    }

    /// <summary>
    /// Рассылка по категории: только устройства с включённым тумблером
    /// (<c>(Categories &amp; flag) != 0</c>), с троттлингом по контракту.
    /// Подавленные companyNews копятся и добавляются к следующей отправке
    /// строкой «и ещё N новостей».
    /// </summary>
    public async Task<DispatchOutcome> DispatchToCategoryAsync(
        PushCategory category,
        NotificationType type,
        IReadOnlyDictionary<string, string>? args = null,
        CancellationToken ct = default)
    {
        if (!throttle.TryPass(category, out var skipped))
        {
            log.LogInformation("Push {Type} ({Category}) подавлен троттлингом", type, category);
            return new DispatchOutcome(0, 0, 0);
        }

        if (skipped > 0 && category == PushCategory.CompanyNews)
        {
            var patched = new Dictionary<string, string>(
                args ?? new Dictionary<string, string>());
            var body = patched.GetValueOrDefault("body", string.Empty);
            patched["body"] = string.IsNullOrWhiteSpace(body)
                ? $"И ещё {skipped} новостей"
                : $"{body} — и ещё {skipped} новостей";
            args = patched;
        }

        var mask = (int)category;
        var tokens = await db.DeviceTokens
            .Where(d => !d.Disabled && (d.Categories & mask) != 0)
            .Select(d => d.Token)
            .ToListAsync(ct);
        return await SendAsync(tokens, type, args, ct);
    }

    /// <summary>
    /// Категория пуша по его типу: learning-типы считаются категорией
    /// «Обучение», типы мира — своими категориями; Test/Custom вне категорий
    /// (шлются всем — ручная админская рассылка и диагностика).
    /// </summary>
    private static PushCategory? MapCategory(NotificationType type) => type switch
    {
        NotificationType.AchievementUnlocked => PushCategory.Learning,
        NotificationType.ReviewDue => PushCategory.Learning,
        NotificationType.StreakReminder => PushCategory.Learning,
        NotificationType.WorldAlert => PushCategory.WorldAlerts,
        NotificationType.CycleEvent => PushCategory.CycleEvents,
        NotificationType.CompanyNews => PushCategory.CompanyNews,
        NotificationType.CalendarDigest => PushCategory.CalendarDigest,
        _ => null,
    };

    private async Task<DispatchOutcome> SendAsync(
        IReadOnlyCollection<string> tokens,
        NotificationType type,
        IReadOnlyDictionary<string, string>? args,
        CancellationToken ct)
    {
        if (tokens.Count == 0) return new DispatchOutcome(0, 0, 0);

        var message = Build(type, args ?? new Dictionary<string, string>());
        var result = await sender.SendAsync(tokens, message, ct);

        if (result.InvalidTokens.Count > 0)
        {
            // Токен уникален глобально — гасим по значению, без привязки к пользователю.
            await db.DeviceTokens
                .Where(d => result.InvalidTokens.Contains(d.Token))
                .ExecuteUpdateAsync(s => s.SetProperty(d => d.Disabled, true), ct);
        }

        log.LogInformation(
            "Push {Type}: целей {Targeted}, отправлено {Sent}, отключено токенов {Bad}",
            type, tokens.Count, result.Sent, result.InvalidTokens.Count);

        return new DispatchOutcome(tokens.Count, result.Sent, result.InvalidTokens.Count);
    }

    /// Заголовок/текст + deep-link route (в Data["route"]) на каждый тип.
    /// Текст можно переопределить через args["title"]/args["body"].
    private static PushMessage Build(NotificationType type, IReadOnlyDictionary<string, string> a)
    {
        string Arg(string key, string fallback) => a.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v : fallback;

        return type switch
        {
            NotificationType.AchievementUnlocked => new PushMessage(
                Arg("title", "Новое достижение"),
                Arg("body", "Ты открыл достижение в Aloria."),
                new Dictionary<string, string> { ["type"] = "achievement", ["route"] = "/progress" }),

            NotificationType.ReviewDue => new PushMessage(
                Arg("title", "Пора повторить"),
                Arg("body", "Несколько карточек ждут разбора — это поможет не забыть."),
                new Dictionary<string, string> { ["type"] = "review", ["route"] = "/learn" }),

            NotificationType.StreakReminder => new PushMessage(
                Arg("title", "Серия под угрозой"),
                Arg("body", "Зайди сегодня, чтобы не потерять серию."),
                new Dictionary<string, string> { ["type"] = "streak", ["route"] = "/learn" }),

            NotificationType.Custom => new PushMessage(
                Arg("title", "Aloria"),
                Arg("body", string.Empty),
                new Dictionary<string, string> { ["type"] = "custom", ["route"] = Arg("route", "/learn") }),

            // Экономический мир: заголовок/текст приходят в args (их формирует
            // триггер в MarketEndpoints), route ведёт в обзор рынка.
            NotificationType.WorldAlert => new PushMessage(
                Arg("title", "Срочное в Алории"),
                Arg("body", string.Empty),
                new Dictionary<string, string> { ["type"] = "worldAlert", ["route"] = "/market" }),

            NotificationType.CycleEvent => new PushMessage(
                Arg("title", "Экономика Алории"),
                Arg("body", "Экономический цикл переходит в новую фазу."),
                new Dictionary<string, string> { ["type"] = "cycleEvent", ["route"] = "/market" }),

            NotificationType.CompanyNews => new PushMessage(
                Arg("title", "Новости компаний"),
                Arg("body", string.Empty),
                new Dictionary<string, string> { ["type"] = "companyNews", ["route"] = "/market" }),

            NotificationType.CalendarDigest => new PushMessage(
                Arg("title", "Календарь дня"),
                Arg("body", "Смотри, что сегодня в календаре Алории."),
                new Dictionary<string, string> { ["type"] = "calendarDigest", ["route"] = "/market" }),

            _ => new PushMessage(
                Arg("title", "Aloria"),
                Arg("body", "Тестовое уведомление — всё работает."),
                new Dictionary<string, string> { ["type"] = "test", ["route"] = "/learn" }),
        };
    }
}

/// <summary>Итог рассылки: сколько устройств в цели, сколько ушло, сколько погашено.</summary>
public record DispatchOutcome(int Targeted, int Sent, int Disabled);
