namespace Aloria.Api.Domain;

/// <summary>
/// Состояние разнесённого повторения (recall) одного урока для пользователя.
/// Упрощённый SM-2: при «вспомнил» интервал растёт, при «не совсем» — сбрасывается.
/// Запись создаётся, когда пользователь впервые оценивает карточку recall.
/// </summary>
public class ReviewItem
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }
    public User? User { get; set; }

    public Guid LessonId { get; set; }
    public Lesson? Lesson { get; set; }

    /// Сколько раз подряд успешно вспомнили.
    public int Repetitions { get; set; }

    /// Коэффициент лёгкости (SM-2), стартует с 2.5, не ниже 1.3.
    public double EaseFactor { get; set; } = 2.5;

    /// Текущий интервал в днях.
    public int IntervalDays { get; set; }

    /// Когда карточка снова станет «к повторению».
    public DateTime NextDueAt { get; set; }

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
