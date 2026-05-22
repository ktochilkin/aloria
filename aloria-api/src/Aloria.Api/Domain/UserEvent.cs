namespace Aloria.Api.Domain;

/// <summary>
/// Маркеры одноразовых событий пользователя — например, «открыл первую
/// позицию». Используется как идемпотентный триггер для ачивок типа
/// FirstPositionOpened: повторное событие с тем же Code просто игнорируется.
/// </summary>
public class UserEvent
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public string Code { get; set; } = string.Empty;
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}
