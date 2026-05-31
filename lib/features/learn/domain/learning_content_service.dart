import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';

/// Загрузка спирального учебного контента из aloria-api.
///
/// Структура API (r11):
///   GET /api/v1/stages              — список этапов с прогрессом
///   GET /api/v1/stages/{slug}       — этап + уроки с разметкой концепций + практика
///   GET /api/v1/learning/lessons/{id} — полное тело урока (markdown)
///
/// Иконки и цвета этапов берутся из бэка (icon, tint в stages.json), но
/// fallback есть в [iconFor]/[tintFor] на случай неизвестного slug.
class LearningContentService {
  LearningContentService(this._client);

  final LearningApiClient _client;

  /// Загружает все этапы курса с уроками и требованиями практики.
  /// Один запрос на список + один на каждый этап. Тела уроков загружаются
  /// уже в `lesson_page.dart` лениво по `fetchLesson(id)`.
  Future<List<LearningSection>> loadSections({String? portfolioId}) async {
    final stagesRaw = await _client.fetchStages(portfolioId: portfolioId);
    if (stagesRaw.isEmpty) return const [];

    final result = <LearningSection>[];
    for (final stageSummary in stagesRaw) {
      final slug = (stageSummary['slug'] as String?) ?? '';
      if (slug.isEmpty) continue;

      final detail = await _client.fetchStage(slug, portfolioId: portfolioId);
      final stageJson =
          (detail['stage'] as Map?)?.cast<String, dynamic>() ?? stageSummary;

      final lessonsRaw = (detail['lessons'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final practiceRaw = (detail['practice'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final lessons = lessonsRaw.map(_mapLessonSummary).toList(growable: false);

      final lessonsCompleted = lessons.where((l) => l.serverCompleted).length;
      final practice = practiceRaw.map(StagePractice.fromJson).toList(growable: false);
      final practiceFulfilled = practice.where((p) => p.fulfilled).length;
      final practiceTotal =
          practice.where((p) => !p.isOptional).length;

      result.add(LearningSection(
        id: slug,
        title: (stageJson['title'] as String?) ?? slug,
        subtitle: (stageJson['subtitle'] as String?) ?? '',
        icon: iconFor(stageJson['icon'] as String? ?? slug),
        tint: tintFor(stageJson['tint'] as String? ?? slug),
        lessons: lessons,
        goal: stageJson['goal'] as String?,
        targetMinutes: (stageJson['targetMinutes'] as num?)?.toInt(),
        isOptional: (stageJson['isOptional'] as bool?) ?? false,
        status: _parseStatus(stageSummary['status'] as String?),
        lessonsTotal: (stageSummary['lessonsTotal'] as num?)?.toInt()
            ?? lessons.length,
        lessonsCompleted: (stageSummary['lessonsCompleted'] as num?)?.toInt()
            ?? lessonsCompleted,
        practiceTotal: (stageSummary['practiceTotal'] as num?)?.toInt()
            ?? practiceTotal,
        practiceFulfilled: (stageSummary['practiceFulfilled'] as num?)?.toInt()
            ?? practiceFulfilled,
        practice: practice,
      ));
    }
    return result;
  }

  Future<Lesson?> loadLesson(String serverLessonId) async {
    final full = await _client.fetchLesson(serverLessonId);
    return _mapLessonBody(full);
  }

  Future<String> loadIntro() async => '';

  /// Маппит сокращённое представление урока из ответа /stages/{slug}:
  /// уже содержит slug, title, description, концепции, флаги — но не тело.
  Lesson _mapLessonSummary(Map<String, dynamic> json) {
    List<LessonConceptRef> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LessonConceptRef.fromJson)
          .toList(growable: false);
    }

    final slug = (json['slug'] as String?) ?? '';

    return Lesson(
      id: slug,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      academicDefinition: '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      body: '',
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      group: json['group'] as String?,
      serverId: json['id'] as String?,
      // У краткого Lesson нет тела/квиза, но есть hasQuiz — серверный квиз
      // подгружается на странице урока.
      serverQuizId: (json['hasQuiz'] as bool? ?? false) ? 'pending' : null,
      serverCompleted: (json['completed'] as bool?) ?? false,
      introduces: parseList(json['introduces']),
      deepens: parseList(json['deepens']),
      applies: parseList(json['applies']),
      isCapstone: (json['isCapstone'] as bool?) ?? false,
      roleHint: json['roleHint'] as String?,
      practiceRequirementCode: json['practiceRequirementCode'] as String?,
    );
  }

  /// Маппит полное тело урока из ответа /learning/lessons/{id}. Используется
  /// в [loadLesson] для подгрузки тела при заходе на страницу урока.
  Lesson? _mapLessonBody(Map<String, dynamic> json) {
    if (json.isEmpty) return null;
    final slug = (json['slug'] as String?) ?? '';
    if (slug.isEmpty) return null;

    final quizJson = json['quiz'];
    final hasQuiz = quizJson is Map<String, dynamic>;
    final quizId = hasQuiz ? quizJson['id'] as String? : null;

    return Lesson(
      id: slug,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      academicDefinition: (json['academicDefinition'] as String?) ?? '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      body: ((json['bodyMd'] as String?) ?? '').trim(),
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      practiceSymbol: json['practiceSymbol'] as String?,
      practiceText: json['practiceText'] as String?,
      recallPrompt: json['recallPrompt'] as String?,
      recallAnswer: json['recallAnswer'] as String?,
      group: json['group'] as String?,
      serverId: json['id'] as String?,
      serverQuizId: quizId,
    );
  }

  static LearningStageStatus _parseStatus(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'inprogress':
        return LearningStageStatus.inProgress;
      case 'completed':
        return LearningStageStatus.completed;
      default:
        return LearningStageStatus.notStarted;
    }
  }

  /// Иконка этапа. На входе — либо имя Material-иконки (из stages.json),
  /// либо slug этапа (fallback).
  static IconData iconFor(String key) {
    switch (key) {
      // Имена иконок из stages.json
      case 'lightbulb_outline':
        return Icons.lightbulb_outline;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'business':
        return Icons.business;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'category':
        return Icons.category;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'show_chart':
        return Icons.show_chart;
      case 'park':
        return Icons.park;
      case 'account_balance':
        return Icons.account_balance;
      case 'flash_on':
        return Icons.flash_on;
      // Fallback по slug этапа
      case 'why-market':
        return Icons.lightbulb_outline;
      case 'first-trade':
        return Icons.rocket_launch;
      case 'stocks':
        return Icons.business;
      case 'bonds':
        return Icons.receipt_long;
      case 'funds':
        return Icons.category;
      case 'portfolio':
        return Icons.pie_chart;
      case 'active-trading':
        return Icons.show_chart;
      default:
        return Icons.book;
    }
  }

  /// Цвет-акцент этапа. На входе — либо токен из stages.json, либо slug.
  static Color tintFor(String key) {
    switch (key) {
      case 'primary':
        return const Color(0xFF5D8CFF);
      case 'secondary':
        return const Color(0xFFFF9E7C);
      case 'success':
        return const Color(0xFF37B38A);
      case 'warning':
        return const Color(0xFFF5C24D);
      // Fallback по slug этапа
      case 'why-market':
      case 'first-trade':
        return const Color(0xFFF5C24D);
      case 'stocks':
      case 'bonds':
      case 'funds':
      case 'portfolio':
        return const Color(0xFF37B38A);
      case 'active-trading':
        return const Color(0xFFFF9E7C);
      default:
        return const Color(0xFF5D8CFF);
    }
  }

  LearningSection? findSectionById(List<LearningSection> sections, String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  Lesson? findLessonById(LearningSection section, String lessonId) {
    for (final l in section.lessons) {
      if (l.id == lessonId) return l;
    }
    return null;
  }
}
