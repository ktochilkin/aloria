import 'package:flutter/material.dart';

/// Статус этапа спирального курса.
enum LearningStageStatus { notStarted, inProgress, completed }

/// Этап обучения (термин бэка — Section, но в UI это спиральный этап).
/// Замкнут вокруг одного класса инструментов или одной задачи. Содержит
/// уроки + капстоун-практику.
class LearningSection {
  const LearningSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.lessons,
    this.goal,
    this.targetMinutes,
    this.isOptional = false,
    this.status = LearningStageStatus.notStarted,
    this.lessonsTotal = 0,
    this.lessonsCompleted = 0,
    this.practiceTotal = 0,
    this.practiceFulfilled = 0,
    this.practice = const [],
  });

  /// `slug` этапа в API (например, `first-trade`).
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final List<Lesson> lessons;

  /// Спиральный курс (r11).
  final String? goal;
  final int? targetMinutes;
  final bool isOptional;
  final LearningStageStatus status;
  final int lessonsTotal;
  final int lessonsCompleted;
  final int practiceTotal;
  final int practiceFulfilled;
  final List<StagePractice> practice;

  LearningSection copyWith({
    List<Lesson>? lessons,
    String? goal,
    int? targetMinutes,
    bool? isOptional,
    LearningStageStatus? status,
    int? lessonsTotal,
    int? lessonsCompleted,
    int? practiceTotal,
    int? practiceFulfilled,
    List<StagePractice>? practice,
  }) {
    return LearningSection(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      tint: tint,
      lessons: lessons ?? this.lessons,
      goal: goal ?? this.goal,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      isOptional: isOptional ?? this.isOptional,
      status: status ?? this.status,
      lessonsTotal: lessonsTotal ?? this.lessonsTotal,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      practiceTotal: practiceTotal ?? this.practiceTotal,
      practiceFulfilled: practiceFulfilled ?? this.practiceFulfilled,
      practice: practice ?? this.practice,
    );
  }
}

/// Ссылка на концепцию в контексте урока (slug, отображаемое имя, глубина).
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
        slug: (json['slug'] as String?) ?? '',
        title: (json['title'] as String?) ?? (json['slug'] as String? ?? ''),
        depth: (json['depth'] as num?)?.toInt() ?? 1,
      );
}

/// Урок раздела обучения.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.academicDefinition,
    required this.imageUrl,
    required this.body,
    this.estimatedMinutes,
    this.practiceSymbol,
    this.practiceText,
    this.recallPrompt,
    this.recallAnswer,
    this.group,
    this.quiz = const [],
    this.serverId,
    this.serverQuizId,
    this.serverCompleted = false,
    this.introduces = const [],
    this.deepens = const [],
    this.applies = const [],
    this.isCapstone = false,
    this.roleHint,
    this.practiceRequirementCode,
  });

  final String id;
  final String title;
  final String description;
  final String academicDefinition;
  final String imageUrl;
  final String body;
  final int? estimatedMinutes;

  /// Опциональная связка «попробуй вживую» (см. backend Lesson.Practice*).
  final String? practiceSymbol;
  final String? practiceText;

  /// Карточка retrieval-practice (см. backend Lesson.Recall*).
  final String? recallPrompt;
  final String? recallAnswer;

  /// Глава внутри этапа (необязательно).
  final String? group;

  final List<QuizQuestion> quiz;
  final String? serverId;
  final String? serverQuizId;

  /// Урок отмечен пройденным на бэке.
  final bool serverCompleted;

  /// Спиральный курс (r11).
  final List<LessonConceptRef> introduces;
  final List<LessonConceptRef> deepens;
  final List<LessonConceptRef> applies;

  /// Финальный урок этапа — в UI подсвечивается как капстоун.
  final bool isCapstone;

  /// Подсказка UI о роли в спирали: `introduce` / `deepen` / `apply`.
  final String? roleHint;

  /// Код требования практики, к которому привязан урок (для кнопки
  /// «к практике этапа»).
  final String? practiceRequirementCode;

  bool get hasQuiz => quiz.isNotEmpty || serverQuizId != null;
  bool get hasServerQuiz => serverQuizId != null;

  /// Все концепции урока (Introduce + Deepen + Apply) одним списком —
  /// для скрытых-данных. Дубли по slug убраны.
  List<LessonConceptRef> get allConcepts {
    final seen = <String>{};
    final result = <LessonConceptRef>[];
    for (final c in [...introduces, ...deepens, ...applies]) {
      if (seen.add(c.slug)) result.add(c);
    }
    return result;
  }

  /// Только возвращающиеся концепции (Deepen + Apply) — для бейджей в
  /// шапке урока. Introduce не показываем: первая встреча с концепцией
  /// и есть весь урок про неё, метка излишня.
  List<LessonConceptRef> get returningConcepts {
    final seen = <String>{};
    final result = <LessonConceptRef>[];
    for (final c in [...deepens, ...applies]) {
      if (seen.add(c.slug)) result.add(c);
    }
    return result;
  }
}

/// Требование практики этапа (капстоун).
class StagePractice {
  const StagePractice({
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

  factory StagePractice.fromJson(Map<String, dynamic> json) => StagePractice(
        id: (json['id'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'Custom',
        isOptional: (json['isOptional'] as bool?) ?? false,
        rewardBuyingPower: (json['rewardBuyingPower'] as num?)?.toInt() ?? 0,
        fulfilled: (json['fulfilled'] as bool?) ?? false,
      );
}

/// Один вопрос мини-теста с одиночным выбором (для legacy frontmatter quiz).
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return QuizQuestion(
      question: (json['question'] as String?)?.trim() ?? '',
      options: options,
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: (json['explanation'] as String?)?.trim(),
    );
  }
}
