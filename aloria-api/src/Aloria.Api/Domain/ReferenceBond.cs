namespace Aloria.Api.Domain;

/// <summary>
/// Облигация в справочнике-каталоге мира Алории: эмитент, кредитное качество
/// и купонный график в терминах мировых дней режиссёра.
/// </summary>
public class ReferenceBond
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;

    /// <summary>Тикер эмитента из каталога (null для гособлигаций).</summary>
    public string? IssuerSymbol { get; set; }

    /// <summary>Кредитное качество: Gov | A | Bbb | Bb.</summary>
    public string Quality { get; set; } = string.Empty;

    /// <summary>Купон за цикл (доля от номинала).</summary>
    public double CouponPerCycle { get; set; }

    /// <summary>Периодичность купона в мировых днях.</summary>
    public int CouponEveryDays { get; set; }

    /// <summary>Позиция в каталоге (порядок, в котором прислал режиссёр).</summary>
    public int Order { get; set; }
}
