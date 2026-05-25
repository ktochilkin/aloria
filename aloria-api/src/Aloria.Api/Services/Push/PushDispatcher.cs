using Aloria.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace Aloria.Api.Services.Push;

/// <summary>
/// Единая точка отправки пушей: по типу собирает сообщение, берёт активные
/// токены, шлёт через <see cref="IPushSender"/> и гасит мёртвые токены.
/// Адресация — одному пользователю (<see cref="DispatchAsync"/>) или всем
/// (<see cref="DispatchToAllAsync"/>). Вызывается только вручную (эндпоинты),
/// автоматических триггеров нет.
/// </summary>
public class PushDispatcher(AloriaDbContext db, IPushSender sender, ILogger<PushDispatcher> log)
{
    /// Отправка одному пользователю — на все его активные устройства.
    public async Task<DispatchOutcome> DispatchAsync(
        Guid userId,
        NotificationType type,
        IReadOnlyDictionary<string, string>? args = null,
        CancellationToken ct = default)
    {
        var tokens = await db.DeviceTokens
            .Where(d => d.UserId == userId && !d.Disabled)
            .Select(d => d.Token)
            .ToListAsync(ct);
        return await SendAsync(tokens, type, args, ct);
    }

    /// Рассылка всем — на все активные устройства всех пользователей.
    public async Task<DispatchOutcome> DispatchToAllAsync(
        NotificationType type,
        IReadOnlyDictionary<string, string>? args = null,
        CancellationToken ct = default)
    {
        var tokens = await db.DeviceTokens
            .Where(d => !d.Disabled)
            .Select(d => d.Token)
            .ToListAsync(ct);
        return await SendAsync(tokens, type, args, ct);
    }

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

            _ => new PushMessage(
                Arg("title", "Aloria"),
                Arg("body", "Тестовое уведомление — всё работает."),
                new Dictionary<string, string> { ["type"] = "test", ["route"] = "/learn" }),
        };
    }
}

/// <summary>Итог рассылки: сколько устройств в цели, сколько ушло, сколько погашено.</summary>
public record DispatchOutcome(int Targeted, int Sent, int Disabled);
