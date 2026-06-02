namespace Aloria.Api.Domain;

public enum StageStatus
{
    NotStarted = 0,
    InProgress = 1,
    Completed = 2,
}

/// <summary>
/// Денормализованный прогресс пользователя по этапу. Пересчитывается
/// ProgressUpdater при изменениях LessonCompletions и PracticeFulfillments.
/// </summary>
public class UserStageProgress
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid SectionId { get; set; }

    public StageStatus Status { get; set; }
    public int LessonsCompletedCount { get; set; }
    public int PracticeFulfilledCount { get; set; }

    public DateTime? StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
