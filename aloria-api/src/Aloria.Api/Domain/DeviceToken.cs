namespace Aloria.Api.Domain;

/// <summary>
/// Push-токен устройства пользователя (FCM registration token). У одного
/// пользователя может быть несколько устройств. Мёртвые токены помечаются
/// Disabled (FCM вернул UNREGISTERED) и не используются при рассылке.
/// </summary>
public class DeviceToken
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    /// FCM registration token устройства.
    public string Token { get; set; } = string.Empty;

    /// ios | android | web — для диагностики и будущей платформенной логики.
    public string Platform { get; set; } = string.Empty;

    public bool Disabled { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
}
