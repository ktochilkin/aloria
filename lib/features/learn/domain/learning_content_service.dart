import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:aloria/features/learn/domain/models.dart';

class LearningContentService {
  static const String _sectionsPath = 'assets/lessons/sections.json';
  static const String _introPath = 'assets/lessons/intro.md';
  static const String _lessonsBasePath = 'assets/lessons';

  Future<List<LearningSection>> loadSections() async {
    try {
      final sectionsJson = await rootBundle.loadString(_sectionsPath);
      final data = jsonDecode(sectionsJson) as Map<String, dynamic>;
      final sectionsData = data['sections'] as List;

      final sections = <LearningSection>[];
      
      for (final sectionData in sectionsData) {
        final section = LearningSection.fromJson(sectionData as Map<String, dynamic>);
        final lessons = await _loadLessonsForSection(section.id);
        sections.add(section.copyWith(lessons: lessons));
      }

      return sections;
    } catch (e) {
      print('Error loading sections: $e');
      return [];
    }
  }

  Future<List<String>> loadIntro() async {
    try {
      final content = await rootBundle.loadString(_introPath);
      return content
          .split('\n\n')
          .where((p) => p.trim().isNotEmpty)
          .toList();
    } catch (e) {
      print('Error loading intro: $e');
      return [];
    }
  }

  Future<List<Lesson>> _loadLessonsForSection(String sectionId) async {
    final lessons = <Lesson>[];
    
    // List of lesson files for each section
    final lessonFiles = _getLessonFilesForSection(sectionId);
    
    for (final file in lessonFiles) {
      try {
        final path = '$_lessonsBasePath/$sectionId/$file';
        final lesson = await _loadLesson(path);
        if (lesson != null) {
          lessons.add(lesson);
        }
      } catch (e) {
        print('Error loading lesson $file: $e');
      }
    }
    
    return lessons;
  }

  List<String> _getLessonFilesForSection(String sectionId) {
    switch (sectionId) {
      case 'trading-basics':
        return [
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
        return [
          '01-dividends.md',
          '02-portfolio.md',
          '03-etf.md',
        ];
      default:
        return [];
    }
  }

  Future<Lesson?> _loadLesson(String path) async {
    try {
      final content = await rootBundle.loadString(path);
      return _parseMarkdownLesson(content);
    } catch (e) {
      print('Error loading lesson from $path: $e');
      return null;
    }
  }

  Lesson? _parseMarkdownLesson(String content) {
    // Split frontmatter and body
    final parts = content.split('---');
    if (parts.length < 3) return null;

    final frontmatter = parts[1].trim();
    final body = parts[2].trim();

    // Parse frontmatter
    final metadata = <String, String>{};
    for (final line in frontmatter.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final key = line.substring(0, colonIndex).trim();
        final value = line.substring(colonIndex + 1).trim();
        metadata[key] = value;
      }
    }

    // Parse body into paragraphs
    final paragraphs = body
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Lesson(
      id: metadata['id'] ?? '',
      title: metadata['title'] ?? '',
      description: metadata['description'] ?? '',
      academicDefinition: metadata['academicDefinition'] ?? '',
      imageUrl: metadata['imageUrl'] ?? '',
      body: paragraphs,
    );
  }

  LearningSection? findSectionById(List<LearningSection> sections, String id) {
    try {
      return sections.firstWhere((section) => section.id == id);
    } catch (e) {
      return null;
    }
  }

  Lesson? findLessonById(LearningSection section, String lessonId) {
    try {
      return section.lessons.firstWhere((lesson) => lesson.id == lessonId);
    } catch (e) {
      return null;
    }
  }
}
