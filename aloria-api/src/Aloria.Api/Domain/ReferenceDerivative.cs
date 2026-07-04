namespace Aloria.Api.Domain;

/// <summary>
/// Дериватив в справочнике-каталоге мира Алории. Пока деривативы в мире не
/// торгуются и каталог приходит с пустым списком, но схема их поддерживает.
/// </summary>
public class ReferenceDerivative
{
    public Guid Id { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;

    /// <summary>Тип дериватива (например, Futures).</summary>
    public string Type { get; set; } = string.Empty;

    /// <summary>Тикер базового актива из каталога.</summary>
    public string? UnderlyingSymbol { get; set; }

    public string Description { get; set; } = string.Empty;

    /// <summary>Позиция в каталоге (порядок, в котором прислал режиссёр).</summary>
    public int Order { get; set; }
}
