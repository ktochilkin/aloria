// Модели спирального учебного курса (r11). См. backend /api/v1/stages,
// /api/v1/concepts и сопровождающие документации в /aloria-api/.../Domain/.

enum StageStatus { notStarted, inProgress, completed }

StageStatus _parseStageStatus(String? raw) {
  switch (raw) {
    case 'inprogress':
    case 'inProgress':
      return StageStatus.inProgress;
    case 'completed':
      return StageStatus.completed;
    default:
      return StageStatus.notStarted;
  }
}

enum ConceptRole { introduce, deepen, apply }

enum ConceptMasteryLevel { none, familiar, understands, applied }

ConceptMasteryLevel _parseMastery(String? raw) {
  switch (raw) {
    case 'familiar':
      return ConceptMasteryLevel.familiar;
    case 'understands':
      return ConceptMasteryLevel.understands;
    case 'applied':
      return ConceptMasteryLevel.applied;
    default:
      return ConceptMasteryLevel.none;
  }
}

/// Сводка этапа в общем списке.
class StageSummary {
  const StageSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.order,
    required this.kind,
    required this.isOptional,
    required this.icon,
    required this.tint,
    required this.goal,
    required this.targetMinutes,
    required this.lessonsTotal,
    required this.lessonsCompleted,
    required this.practiceTotal,
    required this.practiceFulfilled,
    required this.status,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final int order;
  final String kind;
  final bool isOptional;
  final String? icon;
  final String? tint;
  final String? goal;
  final int? targetMinutes;
  final int lessonsTotal;
  final int lessonsCompleted;
  final int practiceTotal;
  final int practiceFulfilled;
  final StageStatus status;

  factory StageSummary.fromJson(Map<String, dynamic> json) => StageSummary(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        subtitle: (json['subtitle'] as String?) ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        kind: (json['kind'] as String?) ?? 'stage',
        isOptional: (json['isOptional'] as bool?) ?? false,
        icon: json['icon'] as String?,
        tint: json['tint'] as String?,
        goal: json['goal'] as String?,
        targetMinutes: (json['targetMinutes'] as num?)?.toInt(),
        lessonsTotal: (json['lessonsTotal'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (json['lessonsCompleted'] as num?)?.toInt() ?? 0,
        practiceTotal: (json['practiceTotal'] as num?)?.toInt() ?? 0,
        practiceFulfilled: (json['practiceFulfilled'] as num?)?.toInt() ?? 0,
        status: _parseStageStatus(json['status'] as String?),
      );
}

/// Ссылка на концепцию в контексте урока: slug, title, текущая глубина.
class LessonConceptRef {
  const LessonConceptRef({
    required this.slug,
    required this.title,
    required this.depth,
  });

  final String slug;
  final String title;
  final int depth;

  factory LessonConceptRef.fromJson(Map<String, dynamic> json) =>
      LessonConceptRef(
        slug: json['slug'] as String,
        title: (json['title'] as String?) ?? json['slug'] as String,
        depth: (json['depth'] as num?)?.toInt() ?? 1,
      );
}

/// Урок внутри детального ответа /api/v1/stages/{slug}.
class StageLesson {
  const StageLesson({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.estimatedMinutes,
    required this.order,
    required this.group,
    required this.roleHint,
    required this.isCapstone,
    required this.practiceRequirementCode,
    required this.hasQuiz,
    required this.completed,
    required this.introduces,
    required this.deepens,
    required this.applies,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? imageUrl;
  final int? estimatedMinutes;
  final int order;
  final String? group;
  final String? roleHint;
  final bool isCapstone;
  final String? practiceRequirementCode;
  final bool hasQuiz;
  final bool completed;
  final List<LessonConceptRef> introduces;
  final List<LessonConceptRef> deepens;
  final List<LessonConceptRef> applies;

  factory StageLesson.fromJson(Map<String, dynamic> json) {
    List<LessonConceptRef> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LessonConceptRef.fromJson)
          .toList(growable: false);
    }

    return StageLesson(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      group: json['group'] as String?,
      roleHint: json['roleHint'] as String?,
      isCapstone: (json['isCapstone'] as bool?) ?? false,
      practiceRequirementCode: json['practiceRequirementCode'] as String?,
      hasQuiz: (json['hasQuiz'] as bool?) ?? false,
      completed: (json['completed'] as bool?) ?? false,
      introduces: parseList(json['introduces']),
      deepens: parseList(json['deepens']),
      applies: parseList(json['applies']),
    );
  }
}

/// Требование практики этапа — что должен сделать ученик на симуляторе.
class StagePracticeRequirement {
  const StagePracticeRequirement({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.kind,
    required this.isOptional,
    required this.rewardBuyingPower,
    required this.fulfilled,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String kind;
  final bool isOptional;
  final int rewardBuyingPower;
  final bool fulfilled;

  factory StagePracticeRequirement.fromJson(Map<String, dynamic> json) =>
      StagePracticeRequirement(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'Custom',
        isOptional: (json['isOptional'] as bool?) ?? false,
        rewardBuyingPower: (json['rewardBuyingPower'] as num?)?.toInt() ?? 0,
        fulfilled: (json['fulfilled'] as bool?) ?? false,
      );
}

/// Детальный ответ /api/v1/stages/{slug}: метаданные + уроки + практика.
class StageDetail {
  const StageDetail({
    required this.stage,
    required this.lessons,
    required this.practice,
  });

  final StageSummary stage;
  final List<StageLesson> lessons;
  final List<StagePracticeRequirement> practice;

  factory StageDetail.fromJson(Map<String, dynamic> json) {
    final stageJson = (json['stage'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lessonsJson = (json['lessons'] as List?) ?? const [];
    final practiceJson = (json['practice'] as List?) ?? const [];
    return StageDetail(
      stage: StageSummary.fromJson({
        ...stageJson,
        // Detail-endpoint не дублирует прогресс — добавим нули, чтобы
        // структура совпала. При необходимости фронт может перечитать
        // /api/v1/stages для актуальных счётчиков.
        'lessonsTotal': stageJson['lessonsTotal'] ?? lessonsJson.length,
        'lessonsCompleted': stageJson['lessonsCompleted'] ?? 0,
        'practiceTotal': stageJson['practiceTotal'] ?? practiceJson.length,
        'practiceFulfilled': stageJson['practiceFulfilled'] ?? 0,
        'status': stageJson['status'] ?? 'notstarted',
      }),
      lessons: lessonsJson
          .whereType<Map<String, dynamic>>()
          .map(StageLesson.fromJson)
          .toList(growable: false),
      practice: practiceJson
          .whereType<Map<String, dynamic>>()
          .map(StagePracticeRequirement.fromJson)
          .toList(growable: false),
    );
  }
}

/// Концепция в каталоге.
class ConceptSummary {
  const ConceptSummary({
    required this.slug,
    required this.title,
    required this.shortDefinition,
    required this.iconName,
    required this.order,
    required this.level,
  });

  final String slug;
  final String title;
  final String shortDefinition;
  final String? iconName;
  final int order;
  final ConceptMasteryLevel level;

  factory ConceptSummary.fromJson(Map<String, dynamic> json) => ConceptSummary(
        slug: json['slug'] as String,
        title: json['title'] as String,
        shortDefinition: (json['shortDefinition'] as String?) ?? '',
        iconName: json['iconName'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        level: _parseMastery(json['level'] as String?),
      );
}

/// Одно появление концепции в курсе (для биографии в bottom sheet).
class ConceptOccurrence {
  const ConceptOccurrence({
    required this.stageSlug,
    required this.stageTitle,
    required this.lessonSlug,
    required this.lessonTitle,
    required this.lessonId,
    required this.depth,
  });

  final String stageSlug;
  final String stageTitle;
  final String lessonSlug;
  final String lessonTitle;
  final String lessonId;
  final int depth;

  factory ConceptOccurrence.fromJson(Map<String, dynamic> json) =>
      ConceptOccurrence(
        stageSlug: json['stageSlug'] as String,
        stageTitle: json['stageTitle'] as String,
        lessonSlug: json['lessonSlug'] as String,
        lessonTitle: json['lessonTitle'] as String,
        lessonId: json['lessonId'] as String,
        depth: (json['depth'] as num?)?.toInt() ?? 1,
      );
}

/// Детали концепции: каталог-данные + биография в курсе.
class ConceptDetail {
  const ConceptDetail({
    required this.summary,
    required this.introductions,
    required this.deepenings,
    required this.applications,
  });

  final ConceptSummary summary;
  final List<ConceptOccurrence> introductions;
  final List<ConceptOccurrence> deepenings;
  final List<ConceptOccurrence> applications;

  factory ConceptDetail.fromJson(Map<String, dynamic> json) {
    List<ConceptOccurrence> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ConceptOccurrence.fromJson)
          .toList(growable: false);
    }

    return ConceptDetail(
      summary: ConceptSummary.fromJson(json),
      introductions: parseList(json['introductions']),
      deepenings: parseList(json['deepenings']),
      applications: parseList(json['applications']),
    );
  }
}

/// Ответ от POST /api/v1/stages/{slug}/practice-events.
class PracticeEventResponse {
  const PracticeEventResponse({
    required this.tradeEventId,
    required this.duplicate,
    required this.fulfilled,
  });

  final String tradeEventId;
  final bool duplicate;
  final List<({String code, String title, String stageSlug})> fulfilled;

  factory PracticeEventResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['fulfilled'] as List?) ?? const [];
    return PracticeEventResponse(
      tradeEventId: (json['tradeEventId'] as String?) ?? '',
      duplicate: (json['duplicate'] as bool?) ?? false,
      fulfilled: list
          .whereType<Map<String, dynamic>>()
          .map((m) => (
                code: m['code'] as String? ?? '',
                title: m['title'] as String? ?? '',
                stageSlug: m['sectionSlug'] as String? ?? '',
              ))
          .toList(growable: false),
    );
  }
}
