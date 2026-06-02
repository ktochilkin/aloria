namespace Aloria.Api.Dtos;

public record AdminSectionDto(
    Guid Id,
    string Slug,
    string Title,
    string Description,
    int Order,
    Guid? PrerequisiteSectionId,
    int LessonCount,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    // r11 spiral
    string Kind,
    bool IsOptional,
    string? IconName,
    string? Tint,
    string? Goal,
    int? TargetMinutes,
    int PracticeCount);

public record AdminSectionInput(
    string Slug,
    string Title,
    string Description,
    int Order,
    Guid? PrerequisiteSectionId,
    // r11 spiral — все опциональны, поэтому admin может частично патчить
    string? Kind,
    bool? IsOptional,
    string? IconName,
    string? Tint,
    string? Goal,
    int? TargetMinutes);

public record AdminLessonListDto(
    Guid Id,
    Guid SectionId,
    string Slug,
    string Title,
    string Description,
    int? EstimatedMinutes,
    int Order,
    int Version,
    bool HasQuiz,
    DateTime UpdatedAt,
    // r11 spiral
    bool IsCapstone,
    string? RoleHint,
    string? PracticeRequirementCode,
    int ConceptCount);

public record AdminLessonDto(
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
    AdminQuizDto? Quiz,
    // r11 spiral
    bool IsCapstone,
    string? RoleHint,
    string? PracticeRequirementCode,
    string? Group,
    string? RecallPrompt,
    string? RecallAnswer,
    string? PracticeText,
    string? PracticeSymbol,
    List<AdminLessonConceptDto> Concepts);

public record AdminLessonInput(
    Guid SectionId,
    string Slug,
    string Title,
    string Description,
    string BodyMd,
    string? ImageUrl,
    int? EstimatedMinutes,
    string? AcademicDefinition,
    int Order,
    bool? IsCapstone,
    string? RoleHint,
    string? PracticeRequirementCode,
    string? Group,
    string? RecallPrompt,
    string? RecallAnswer,
    string? PracticeText,
    string? PracticeSymbol);

public record AdminConceptDto(
    Guid Id,
    string Slug,
    string Title,
    string ShortDefinition,
    string? IconName,
    int Order,
    int LessonsCount,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record AdminConceptInput(
    string Slug,
    string Title,
    string ShortDefinition,
    string? IconName,
    int Order);

public record AdminLessonConceptDto(
    string ConceptSlug,
    string ConceptTitle,
    string Role,
    int Depth);

public record AdminLessonConceptsInput(
    List<string> Introduces,
    List<string> Deepens,
    List<string> Applies);

public record AdminPracticeRequirementDto(
    Guid Id,
    Guid SectionId,
    string Code,
    string Title,
    string Description,
    string Kind,
    string ParamsJson,
    int Order,
    bool IsOptional,
    int RewardBuyingPower,
    string ConceptSlugsJson,
    bool Archived,
    DateTime UpdatedAt);

public record AdminPracticeRequirementInput(
    string Code,
    string Title,
    string Description,
    string Kind,
    string ParamsJson,
    int Order,
    bool IsOptional,
    int RewardBuyingPower,
    string ConceptSlugsJson);

public record AdminQuizDto(
    Guid Id,
    Guid? LessonId,
    string Slug,
    string Title,
    string Description,
    int RewardXp,
    decimal RewardBuyingPower,
    List<AdminQuizQuestionDto> Questions);

public record AdminQuizInput(
    Guid? LessonId,
    string Slug,
    string Title,
    string Description,
    int RewardXp,
    decimal RewardBuyingPower,
    List<AdminQuizQuestionInput> Questions);

public record AdminQuizQuestionDto(
    Guid Id,
    string Text,
    bool AllowsMultiple,
    int Order,
    List<AdminQuizOptionDto> Options);

public record AdminQuizQuestionInput(
    Guid? Id,
    string Text,
    bool AllowsMultiple,
    int Order,
    List<AdminQuizOptionInput> Options);

public record AdminQuizOptionDto(
    Guid Id,
    string Text,
    bool IsCorrect,
    string? Explanation,
    int Order);

public record AdminQuizOptionInput(
    Guid? Id,
    string Text,
    bool IsCorrect,
    string? Explanation,
    int Order);

public record AdminAchievementDto(
    Guid Id,
    string Code,
    string Title,
    string Description,
    string IconName,
    int Condition,
    int ConditionThreshold,
    string? ConditionArg,
    int RewardXp,
    decimal RewardBuyingPower,
    int Order,
    DateTime UpdatedAt);

public record AdminAchievementInput(
    string Code,
    string Title,
    string Description,
    string IconName,
    int Condition,
    int ConditionThreshold,
    string? ConditionArg,
    int RewardXp,
    decimal RewardBuyingPower,
    int Order);

public record AdminUserListDto(
    Guid Id,
    string AlorPortfolioId,
    string? DisplayName,
    int Xp,
    int Level,
    int StreakDays,
    int LessonsCompleted,
    int QuizzesPassed,
    decimal BonusBuyingPower,
    DateTime CreatedAt);

public record AdminUserDetailDto(
    AdminUserListDto User,
    List<AdminGrantDto> Grants,
    List<AdminQuizAttemptDto> Attempts,
    List<AdminAchievementUnlockDto> Achievements);

public record AdminGrantDto(
    Guid Id,
    decimal Amount,
    string Reason,
    string Status,
    DateTime CreatedAt,
    DateTime? CommittedAt);

public record AdminQuizAttemptDto(
    Guid Id,
    Guid QuizId,
    string QuizTitle,
    bool IsPassed,
    int AwardedXp,
    decimal AwardedBuyingPower,
    DateTime AttemptedAt);

public record AdminAchievementUnlockDto(
    Guid AchievementId,
    string Code,
    string Title,
    DateTime UnlockedAt);

public record AdminAuditEntryDto(
    Guid Id,
    string Actor,
    string Action,
    string EntityType,
    string? EntityId,
    string? Details,
    DateTime CreatedAt);

public record AdminManualGrantInput(
    decimal Amount,
    string Reason);

public record AdminLessonCompletionInput(bool Completed);

/// Ручная push-рассылка из админки. Route — опциональный deep-link (по умолчанию /learn).
public record AdminPushInput(
    string Title,
    string Body,
    string? Route);
