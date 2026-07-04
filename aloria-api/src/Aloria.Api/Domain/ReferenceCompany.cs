namespace Aloria.Api.Domain;

/// <summary>
/// Компания-эмитент в справочнике-каталоге мира Алории: лор (тема, история)
/// плюс фундаментальные параметры мира режиссёра. Отдельно от
/// <see cref="Company"/> — ту используют новости/мок-сидер.
/// </summary>
public class ReferenceCompany
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;

    /// <summary>Slug сектора из этого же каталога (связь по значению, без FK).</summary>
    public string SectorSlug { get; set; } = string.Empty;

    /// <summary>Короткая тема компании («системный банк»).</summary>
    public string Theme { get; set; } = string.Empty;

    /// <summary>История/лор компании для чтения в приложении.</summary>
    public string Story { get; set; } = string.Empty;

    /// <summary>Доля прибыли, идущая на дивиденды (0..1).</summary>
    public double Payout { get; set; }

    /// <summary>Долговая нагрузка (0..1).</summary>
    public double Leverage { get; set; }

    /// <summary>Базовая волатильность бумаги (сигма на тик).</summary>
    public double Sigma { get; set; }

    /// <summary>Позиция в каталоге (порядок, в котором прислал режиссёр).</summary>
    public int Order { get; set; }
}
