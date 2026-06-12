namespace Aloria.Api.Domain;

/// <summary>
/// Обращение в поддержку. Создаётся из приложения, когда пользователь
/// столкнулся с системным сбоем («проблема в мире Алории») или хочет
/// сообщить о проблеме. Вместе с обращением сохраняется подробный контекст
/// (параметры заявки, портфель, позиции) для разбора без переписки.
/// </summary>
public class SupportTicket
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    /// Статус: open — ждёт разбора, answered — есть ответ.
    public string Status { get; set; } = "open";

    /// Короткая тема (например, «Не отправилась заявка по SBER»).
    public string Subject { get; set; } = string.Empty;

    /// Код ошибки торговой системы, если был (например, CommandResponseTimeout).
    public string? ErrorCode { get; set; }

    /// Техническое сообщение ошибки.
    public string? ErrorMessage { get; set; }

    /// JSON-снимок контекста: параметры заявки, покупательная способность,
    /// позиции, версия приложения и т.п.
    public string? ContextJson { get; set; }

    /// Комментарий пользователя своими словами (необязательный).
    public string? UserComment { get; set; }

    /// Ответ поддержки (заполняется через админку).
    public string? Answer { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? AnsweredAt { get; set; }
}
