namespace Aloria.Api.Domain;

/// <summary>
/// Фонд (индексный или облигационный) в справочнике-каталоге мира Алории.
/// </summary>
public class ReferenceFund
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;

    /// <summary>true — фонд облигаций, false — фонд акций/индекс.</summary>
    public bool IsBondFund { get; set; }

    public string Description { get; set; } = string.Empty;

    /// <summary>Позиция в каталоге (порядок, в котором прислал режиссёр).</summary>
    public int Order { get; set; }
}
