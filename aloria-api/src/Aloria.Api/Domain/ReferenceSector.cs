namespace Aloria.Api.Domain;

/// <summary>
/// Сектор справочника-каталога мира Алории. Каталог целиком пушит
/// Aloria Director (полная замена), приложение читает его для экрана
/// «про эмитентов и мир». Отдельная таблица от <see cref="Sector"/> —
/// ту используют новости/мок-сидер, здесь живёт лор.
/// </summary>
public class ReferenceSector
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    /// <summary>Позиция в каталоге (порядок, в котором прислал режиссёр).</summary>
    public int Order { get; set; }
}
