import 'dart:convert';

import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/services.dart';

/// Загрузка и парсинг учебного контента из assets.
///
/// Структура ассетов:
///   assets/lessons/sections.json     — список разделов и метаданные intro
///   assets/lessons/intro.md          — текст вступительной модалки
///   assets/lessons/<sectionId>/*.md  — markdown-файлы уроков по разделу
///
/// Формат урока (markdown):
///   ---
///   id: orders
///   title: Что такое биржа?
///   description: Краткое описание.
///   academicDefinition: ...
///   imageUrl: assets/images/lesson1.jpg
///   estimatedMinutes: 4              # опционально
///   ---
///   Тело урока в markdown...
///
///   ---quiz---                       # опционально, JSON-список вопросов
///   [
///     {
///       "question": "...",
///       "options": ["a", "b", "c"],
///       "correctIndex": 1,
///       "explanation": "..."
///     }
///   ]
class LearningContentService {
  static const String _sectionsPath = 'assets/lessons/sections.json';
  static const String _introPath = 'assets/lessons/intro.md';
  static const String _lessonsBasePath = 'assets/lessons';

  /// Маркер начала блока с тестом внутри файла урока.
  static const String _quizMarker = '---quiz---';

  Future<List<LearningSection>> loadSections() async {
    try {
      final sectionsJson = await rootBundle.loadString(_sectionsPath);
      final data = jsonDecode(sectionsJson) as Map<String, dynamic>;
      final sectionsData = data['sections'] as List;

      final sections = <LearningSection>[];

      for (final sectionData in sectionsData) {
        final section = LearningSection.fromJson(
          sectionData as Map<String, dynamic>,
        );
        final lessons = await _loadLessonsForSection(section.id);
        sections.add(section.copyWith(lessons: lessons));
      }

      return sections;
    } catch (e) {
      // ignore: avoid_print
      print('Error loading sections: $e');
      return const [];
    }
  }

  Future<String> loadIntro() async {
    try {
      return await rootBundle.loadString(_introPath);
    } catch (e) {
      // ignore: avoid_print
      print('Error loading intro: $e');
      return '';
    }
  }

  Future<List<Lesson>> _loadLessonsForSection(String sectionId) async {
    final lessons = <Lesson>[];
    final lessonFiles = _getLessonFilesForSection(sectionId);

    for (final file in lessonFiles) {
      try {
        final path = '$_lessonsBasePath/$sectionId/$file';
        final lesson = await _loadLesson(path);
        if (lesson != null) {
          lessons.add(lesson);
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error loading lesson $file: $e');
      }
    }

    return lessons;
  }

  List<String> _getLessonFilesForSection(String sectionId) {
    switch (sectionId) {
      case 'trading-basics':
        return const [
          '01-orders.md',
          '02-orderbook.md',
          '03-margin.md',
          '04-position.md',
          '05-orderbook_view.md',
          '06-chart_basics.md',
          '07-candles_timeframes.md',
          '08-market_observation.md',
        ];
      case 'investing-basics':
        return const [
          '01-why_invest.md',
          '02-stock_market.md',
          '03-stock.md',
          '04-stock_behavior.md',
          '05-dividends.md',
          '06-investment_risks.md',
        ];
      default:
        return const [];
    }
  }

  Future<Lesson?> _loadLesson(String path) async {
    try {
      final content = await rootBundle.loadString(path);
      return _parseMarkdownLesson(content);
    } catch (e) {
      // ignore: avoid_print
      print('Error loading lesson from $path: $e');
      return null;
    }
  }

  /// Разбирает один файл урока: frontmatter + тело + опциональный блок теста.
  Lesson? _parseMarkdownLesson(String content) {
    final parts = content.split('---');
    if (parts.length < 3) return null;

    final frontmatter = parts[1].trim();
    // Всё, что идёт после второго `---`, это тело + возможно блок теста.
    final afterFrontmatter = parts.sublist(2).join('---').trim();

    final metadata = _parseFrontmatter(frontmatter);
    final (body, quiz) = _splitBodyAndQuiz(afterFrontmatter);

    return Lesson(
      id: metadata['id'] ?? '',
      title: metadata['title'] ?? '',
      description: metadata['description'] ?? '',
      academicDefinition: metadata['academicDefinition'] ?? '',
      imageUrl: metadata['imageUrl'] ?? '',
      body: body.trim(),
      estimatedMinutes: int.tryParse(metadata['estimatedMinutes'] ?? ''),
      quiz: quiz,
    );
  }

  Map<String, String> _parseFrontmatter(String frontmatter) {
    final metadata = <String, String>{};
    for (final line in frontmatter.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      if (key.isEmpty) continue;
      metadata[key] = value;
    }
    return metadata;
  }

  /// Делит хвост markdown-файла на основной текст и (опционально) JSON-блок теста.
  (String body, List<QuizQuestion> quiz) _splitBodyAndQuiz(String tail) {
    final markerIndex = tail.indexOf(_quizMarker);
    if (markerIndex == -1) {
      return (tail, const <QuizQuestion>[]);
    }

    final body = tail.substring(0, markerIndex);
    final quizSection = tail.substring(markerIndex + _quizMarker.length).trim();

    return (body, _parseQuizJson(quizSection));
  }

  List<QuizQuestion> _parseQuizJson(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestion.fromJson)
          .where((q) => q.question.isNotEmpty && q.options.isNotEmpty)
          .toList(growable: false);
    } catch (e) {
      // ignore: avoid_print
      print('Error parsing quiz JSON: $e');
      return const [];
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
