namespace Aloria.Api.Domain;

public enum TradeEventType
{
    OrderPlaced = 1,
    OrderFilled = 2,
    OrderCancelled = 3,
    PositionOpened = 4,
    PositionClosed = 5,
    CouponPaid = 6,
    DividendPaid = 7,
}

/// <summary>
/// Нормализованное торговое событие. Источники: (а) клиент пушит после
/// успешной операции в Aloria-движке через POST /api/v1/stages/{slug}/practice-events;
/// (б) когда подключится прямой стрим с движка — серверный listener пишет
/// сюда же. Один поток — один dispatcher (PracticeEventDispatcher).
/// </summary>
public class TradeEvent
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public TradeEventType Type { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string AssetClass { get; set; } = string.Empty;   // "stock" | "bond" | "fund" | "metal" | "any"
    public decimal Qty { get; set; }
    public decimal? Price { get; set; }
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;

    /// Идемпотентность входа — уникальный ключ от клиента или генерируется по
    /// (orderId, eventType) при поступлении из стрима движка.
    public string IdempotencyKey { get; set; } = string.Empty;

    /// Сырое содержимое события для отладки и расширения.
    public string PayloadJson { get; set; } = "{}";
}
