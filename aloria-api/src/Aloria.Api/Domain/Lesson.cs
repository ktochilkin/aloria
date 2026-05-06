namespace Aloria.Api.Domain;

/// <summary>Урок внутри раздела. Тело — markdown, рендерится в приложении.</summary>
public class Lesson
{
    public Guid Id { get; set; }
    public Guid SectionId { get; set; }
    public Section? Section { get; set; }

    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string BodyMd { get; set; } = string.Empty;
    public string? ImageUrl { get; set; }
    public int? EstimatedMinutes { get; set; }
    public string? AcademicDefinition { get; set; }
    public int Order { get; set; }
    public int Version { get; set; } = 1;

    public Quiz? Quiz { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
