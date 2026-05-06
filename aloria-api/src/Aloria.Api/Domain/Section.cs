namespace Aloria.Api.Domain;

/// <summary>Раздел обучения — корневой узел навигации по урокам.</summary>
public class Section
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Order { get; set; }
    public Guid? PrerequisiteSectionId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<Lesson> Lessons { get; set; } = new();
}
