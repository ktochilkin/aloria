namespace Aloria.Api.Domain;

/// <summary>
/// Этап обучения — корневой узел навигации. В спиральной модели каждый этап
/// замкнут вокруг одного класса инструментов или одной задачи и содержит
/// уроки + капстоун-практику.
/// </summary>
public class Section
{
    public Guid Id { get; set; }
    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Order { get; set; }
    public Guid? PrerequisiteSectionId { get; set; }

    /// Тип записи: "stage" — спиральный этап, "legacy" — раздел старой схемы.
    /// Сейчас все секции — "stage", поле оставлено для миграции в будущем.
    public string Kind { get; set; } = "stage";

    /// Опциональный этап (по желанию ученика — не блокирует завершение курса).
    public bool IsOptional { get; set; }

    /// Имя иконки Material (из sections.json/stages.json).
    public string? IconName { get; set; }

    /// Цветовой токен (из sections.json/stages.json).
    public string? Tint { get; set; }

    /// Короткое обещание навыка — «что узнаю/смогу после этапа».
    public string? Goal { get; set; }

    /// Ориентир по времени прохождения, минуты.
    public int? TargetMinutes { get; set; }

    /// JSON-правило разблокировки этапа: { "requires": [...] }. Если пусто —
    /// этап доступен после предыдущего по Order.
    public string? UnlockRuleJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<Lesson> Lessons { get; set; } = new();
    public List<PracticeRequirement> PracticeRequirements { get; set; } = new();
}
