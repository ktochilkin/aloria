namespace Aloria.Api.Domain;

/// <summary>
/// Расширенный прогресс по уроку: открытие, попытка recall, прохождение квиза.
/// LessonCompletion остаётся как идемпотентная отметка «прошёл» (legacy);
/// эта таблица — для in-progress состояний.
/// </summary>
public class UserLessonProgress
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid LessonId { get; set; }

    public bool Started { get; set; }
    public bool RecallAttempted { get; set; }
    public bool QuizPassed { get; set; }

    public DateTime? FirstOpenedAt { get; set; }
    public DateTime? LastInteractionAt { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
