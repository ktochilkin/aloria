namespace Aloria.Api.Domain;

/// <summary>
/// Запись о выполнении пользователем требования практики. Идемпотентность —
/// по IdempotencyKey (комбинация trade-event-id + requirement-id).
/// </summary>
public class UserPracticeFulfillment
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid PracticeRequirementId { get; set; }

    public DateTime FulfilledAt { get; set; } = DateTime.UtcNow;

    /// Доказательство — JSON со ссылкой на ордер/позицию/событие движка и
    /// кратким снэпшотом: {"orderId":"…","symbol":"…","qty":1,"source":"trade-event"}.
    public string EvidenceJson { get; set; } = "{}";

    /// Уникальный ключ выполнения — защита от двойного зачёта по одному событию.
    public string IdempotencyKey { get; set; } = string.Empty;
}
