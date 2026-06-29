namespace Aloria.Api.Domain;

/// <summary>
/// Компания-эмитент тестовой вселенной (совпадает с тестовыми инструментами
/// TEREX). Тикер <see cref="Symbol"/> — ключ связи с торговым движком и новостями.
/// </summary>
public class Company
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Theme { get; set; } = string.Empty;
    public Guid SectorId { get; set; }
    public Sector? Sector { get; set; }
    public int Order { get; set; }
}
