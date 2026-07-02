namespace Aloria.Api.Domain;

/// <summary>
/// Событие календаря экономического цикла (пишет Aloria Director, читает
/// приложение): отчётности, дивидендные отсечки/выплаты, купоны, погашения,
/// заседания ЦБ. День — мировой день режиссёра (не дата).
/// </summary>
public class CycleCalendarItem
{
    public Guid Id { get; set; }

    /// <summary>Мировой день (сквозной, 1..∞).</summary>
    public int Day { get; set; }

    /// <summary>Тик внутри дня (позиция «когда днём»).</summary>
    public int TickOfDay { get; set; }

    /// <summary>earnings | dividend | coupon | maturity | rate | expiry.</summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>Тикер (null для макро-событий вроде заседания ЦБ).</summary>
    public string? Symbol { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
