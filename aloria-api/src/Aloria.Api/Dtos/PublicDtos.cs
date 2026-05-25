namespace Aloria.Api.Dtos;

public record SectionDto(
    Guid Id,
    string Slug,
    string Title,
    string Description,
    int Order,
    Guid? PrerequisiteSectionId,
    int LessonCount,
    int CompletedCount);

public record LessonSummaryDto(
    Guid Id,
    string Slug,
    string Title,
    string Description,
    string? ImageUrl,
    int? EstimatedMinutes,
    int Order,
    bool HasQuiz,
    bool IsCompleted);

public record LessonDto(
    Guid Id,
    Guid SectionId,
    string Slug,
    string Title,
    string Description,
    string BodyMd,
    string? ImageUrl,
    int? EstimatedMinutes,
    string? AcademicDefinition,
    int Order,
    int Version,
    QuizDto? Quiz,
    string? PracticeSymbol,
    string? PracticeText,
    string? RecallPrompt,
    string? RecallAnswer);

public record QuizDto(
    Guid Id,
    string Slug,
    string Title,
    string Description,
    int RewardXp,
    decimal RewardBuyingPower,
    List<QuizQuestionDto> Questions);

/// <summary>Без is_correct — клиент не должен знать правильные ответы.</summary>
public record QuizQuestionDto(
    Guid Id,
    string Text,
    bool AllowsMultiple,
    int Order,
    List<QuizOptionDto> Options);

public record QuizOptionDto(
    Guid Id,
    string Text,
    int Order);

public record QuizAttemptRequest(List<QuizAnswerInput> Answers);

public record QuizAnswerInput(Guid QuestionId, List<Guid> SelectedOptionIds);

public record QuizAttemptResult(
    bool IsPassed,
    int CorrectCount,
    int TotalQuestions,
    int AwardedXp,
    decimal AwardedBuyingPower,
    string? GrantStatus,
    List<QuestionResultDto> Questions);

public record QuestionResultDto(
    Guid QuestionId,
    bool IsCorrect,
    List<Guid> CorrectOptionIds,
    string? Explanation);

public record AchievementDto(
    Guid Id,
    string Code,
    string Title,
    string Description,
    string IconName,
    int RewardXp,
    decimal RewardBuyingPower,
    bool IsUnlocked,
    DateTime? UnlockedAt,
    int? Progress,
    int? Threshold);

public record ProgressDto(
    int Xp,
    int Level,
    int StreakDays,
    int LessonsCompleted,
    int QuizzesPassed,
    decimal BonusBuyingPower,
    int AchievementsUnlocked,
    int AchievementsTotal);

public record GrantDto(
    Guid Id,
    decimal Amount,
    string Reason,
    string Status,
    DateTime CreatedAt,
    DateTime? CommittedAt);

// ----- Разнесённое повторение (recall) -----------------------------------
public record ReviewGradeRequest(bool Remembered);

public record ReviewGradeResultDto(DateTime NextDueAt, int IntervalDays);

public record DueReviewDto(
    Guid LessonId,
    string SectionSlug,
    string LessonSlug,
    string Title,
    string RecallPrompt,
    string? RecallAnswer);

// ----- Push-устройства ----------------------------------------------------
public record DeviceRegisterRequest(string Token, string? Platform);
