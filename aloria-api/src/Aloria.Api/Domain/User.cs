namespace Aloria.Api.Domain;

/// <summary>
/// Пользователь приложения. Привязан к Алоровскому портфелю.
/// На старте без полноценной аутентификации: identity == AlorPortfolioId.
/// </summary>
public class User
{
    public Guid Id { get; set; }
    public string AlorPortfolioId { get; set; } = string.Empty;
    public string? AlorUserId { get; set; }
    public string? DisplayName { get; set; }

    public int Xp { get; set; }
    public int Level { get; set; } = 1;
    public int StreakDays { get; set; }
    public DateTime? LastActiveDate { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public List<LessonCompletion> LessonCompletions { get; set; } = new();
    public List<QuizAttempt> QuizAttempts { get; set; } = new();
    public List<AchievementUnlock> AchievementUnlocks { get; set; } = new();
    public List<BuyingPowerGrant> Grants { get; set; } = new();
}

public class LessonCompletion
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public Guid LessonId { get; set; }
    public Lesson? Lesson { get; set; }

    public int LessonVersion { get; set; }
    public DateTime CompletedAt { get; set; } = DateTime.UtcNow;
}

public class QuizAttempt
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public Guid QuizId { get; set; }
    public Quiz? Quiz { get; set; }

    public bool IsPassed { get; set; }
    public string AnswersJson { get; set; } = "{}";
    public string IdempotencyKey { get; set; } = string.Empty;

    public int AwardedXp { get; set; }
    public decimal AwardedBuyingPower { get; set; }

    public DateTime AttemptedAt { get; set; } = DateTime.UtcNow;
}

public class AchievementUnlock
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public Guid AchievementId { get; set; }
    public Achievement? Achievement { get; set; }

    public DateTime UnlockedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Запись о начислении виртуальной покупательной способности пользователю.
/// Идемпотентно по IdempotencyKey: повторный POST с тем же ключом вернёт
/// уже выданный результат, не начислит дважды.
/// </summary>
public class BuyingPowerGrant
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty; // "quiz:basics_orders", "achievement:first_trade"
    public string IdempotencyKey { get; set; } = string.Empty;

    public string Status { get; set; } = "pending"; // pending | committed | failed
    public string? FailureReason { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CommittedAt { get; set; }
}
