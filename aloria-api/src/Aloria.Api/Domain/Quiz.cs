namespace Aloria.Api.Domain;

/// <summary>Тест: набор вопросов с вариантами ответов и наградой за прохождение.</summary>
public class Quiz
{
    public Guid Id { get; set; }
    public Guid? LessonId { get; set; }
    public Lesson? Lesson { get; set; }

    public string Slug { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;

    public int RewardXp { get; set; }
    public decimal RewardBuyingPower { get; set; }

    public List<QuizQuestion> Questions { get; set; } = new();

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class QuizQuestion
{
    public Guid Id { get; set; }
    public Guid QuizId { get; set; }
    public Quiz? Quiz { get; set; }

    public string Text { get; set; } = string.Empty;
    public bool AllowsMultiple { get; set; }
    public int Order { get; set; }

    public List<QuizOption> Options { get; set; } = new();
}

public class QuizOption
{
    public Guid Id { get; set; }
    public Guid QuestionId { get; set; }
    public QuizQuestion? Question { get; set; }

    public string Text { get; set; } = string.Empty;
    public bool IsCorrect { get; set; }
    public string? Explanation { get; set; }
    public int Order { get; set; }
}
