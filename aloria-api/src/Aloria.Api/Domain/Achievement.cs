namespace Aloria.Api.Domain;

/// <summary>Условие срабатывания ачивки. Хардкод-список без DSL.</summary>
public enum AchievementCondition
{
    LessonsCompleted = 1,    // ConditionThreshold = N: прошёл N уроков
    QuizzesPassed = 2,       // ConditionThreshold = N: сдал N тестов
    StreakDays = 3,          // ConditionThreshold = N: серия из N дней подряд
    FirstPositionOpened = 4, // открыл первую позицию
    TotalXp = 5              // ConditionThreshold = N: набрал N XP
}

public class Achievement
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string IconName { get; set; } = "emoji_events"; // Material Icon

    public AchievementCondition Condition { get; set; }
    public int ConditionThreshold { get; set; }
    public string? ConditionArg { get; set; } // например, slug секции для условий, привязанных к разделу

    public int RewardXp { get; set; }
    public decimal RewardBuyingPower { get; set; }

    public int Order { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
