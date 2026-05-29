import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';

/// Загрузка учебного контента из aloria-api.
///
/// Структура соответствует бэкенду:
///   GET /api/v1/learning/sections          — разделы (без тел уроков)
///   GET /api/v1/learning/sections/{slug}   — список уроков раздела (без тела)
///   GET /api/v1/learning/lessons/{id}      — урок целиком + опционально тест
///
/// Иконки и цвета разделов выводятся из slug — это атрибут UI и сервер их
/// не отдаёт. Если в будущем понадобятся произвольные иконки, добавим
/// поле в БД.
class LearningContentService {
  LearningContentService(this._client);

  final LearningApiClient _client;

  Future<List<LearningSection>> loadSections({String? portfolioId}) async {
    final sectionsRaw = await _client.fetchSections(portfolioId: portfolioId);
    if (sectionsRaw.isEmpty) return const [];

    final result = <LearningSection>[];
    for (final s in sectionsRaw) {
      final slug = s['slug'] as String? ?? '';
      final detail = await _client.fetchSection(slug, portfolioId: portfolioId);
      final lessonsList = (detail['lessons'] as List? ?? const [])
          .whereType<Map<String, dynamic>>();

      final lessons = <Lesson>[];
      for (final summary in lessonsList) {
        final lessonId = summary['id'] as String;
        final isCompleted = summary['isCompleted'] as bool? ?? false;
        final full = await _client.fetchLesson(lessonId);
        final lesson = _mapLesson(full, serverCompleted: isCompleted);
        if (lesson != null) lessons.add(lesson);
      }

      result.add(LearningSection(
        id: slug,
        title: s['title'] as String? ?? slug,
        subtitle: s['description'] as String? ?? '',
        icon: iconFor(slug),
        tint: tintFor(slug),
        lessons: lessons,
      ));
    }
    return result;
  }

  /// Заглушка под старый API. Бэкенд тело intro-модалки не отдаёт пока.
  Future<String> loadIntro() async => '';

  Lesson? _mapLesson(
    Map<String, dynamic> json, {
    bool serverCompleted = false,
  }) {
    if (json.isEmpty) return null;
    final id = json['slug'] as String? ?? '';
    if (id.isEmpty) return null;

    final quizJson = json['quiz'];
    final hasQuiz = quizJson is Map<String, dynamic>;
    final quizId = hasQuiz ? quizJson['id'] as String? : null;

    return Lesson(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      academicDefinition: json['academicDefinition'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      body: (json['bodyMd'] as String? ?? '').trim(),
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      practiceSymbol: json['practiceSymbol'] as String?,
      practiceText: json['practiceText'] as String?,
      recallPrompt: json['recallPrompt'] as String?,
      recallAnswer: json['recallAnswer'] as String?,
      group: json['group'] as String?,
      serverId: json['id'] as String?,
      serverQuizId: quizId,
      serverCompleted: serverCompleted,
    );
  }

  /// Иконка раздела по его slug (UI-атрибут, сервер иконки не отдаёт).
  /// Публичная: используется и при восстановлении разделов из кэша.
  static IconData iconFor(String slug) {
    switch (slug) {
      case 'start':
        return Icons.rocket_launch;
      case 'investor':
        return Icons.park;
      case 'trader':
        return Icons.show_chart;
      case 'investing-basics':
        return Icons.account_balance;
      case 'trading-basics':
        return Icons.show_chart;
      case 'orders':
        return Icons.flash_on;
      default:
        return Icons.book;
    }
  }

  /// Цвет-акцент раздела по его slug. См. [iconFor].
  static Color tintFor(String slug) {
    switch (slug) {
      case 'start':
        return const Color(0xFFF5C24D);
      case 'investor':
        return const Color(0xFF37B38A);
      case 'trader':
        return const Color(0xFFFF9E7C);
      case 'investing-basics':
        return const Color(0xFF5D8CFF);
      case 'trading-basics':
        return const Color(0xFFFF9E7C);
      case 'orders':
        return const Color(0xFF37B38A);
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
