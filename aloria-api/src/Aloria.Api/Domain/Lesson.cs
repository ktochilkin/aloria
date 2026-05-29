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

    /// Опциональная связка «попробуй вживую»: тикер инструмента и текст задачи.
    /// Если задан текст — в уроке показывается карточка с deep-link в рынок.
    public string? PracticeSymbol { get; set; }
    public string? PracticeText { get; set; }

    /// Опциональная карточка retrieval-practice: вопрос на вспоминание и
    /// эталонный ответ для самопроверки. Расписание повторений — в ReviewItem.
    public string? RecallPrompt { get; set; }
    public string? RecallAnswer { get; set; }

    /// Глава внутри раздела (необязательно). Уроки с одинаковым значением
    /// показываются под общим заголовком-главой в дорожке раздела.
    public string? Group { get; set; }

    public int Order { get; set; }
    public int Version { get; set; } = 1;

    public Quiz? Quiz { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
