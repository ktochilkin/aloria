namespace Aloria.Api.Domain;

/// <summary>
/// Учебная концепция (риск, ликвидность, доходность и т. п.). Поперечное
/// измерение спирального курса: одна концепция проходит через несколько
/// этапов с возрастающей глубиной.
/// </summary>
public class Concept
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string ShortDefinition { get; set; } = string.Empty;
    public string? IconName { get; set; }
    public int Order { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<LessonConcept> Lessons { get; set; } = new();
}
