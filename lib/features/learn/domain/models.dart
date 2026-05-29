import 'package:flutter/material.dart';

class LearningSection {
  const LearningSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.lessons,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final List<Lesson> lessons;

  factory LearningSection.fromJson(Map<String, dynamic> json) {
    return LearningSection(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      icon: _iconFromString(json['icon'] as String),
      tint: _colorFromString(json['tint'] as String),
      lessons: const [], // lessons will be loaded separately
    );
  }

  LearningSection copyWith({List<Lesson>? lessons}) {
    return LearningSection(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      tint: tint,
      lessons: lessons ?? this.lessons,
    );
  }

  static IconData _iconFromString(String iconName) {
    switch (iconName) {
      case 'flash_on':
        return Icons.flash_on;
      case 'park':
        return Icons.park;
      case 'show_chart':
        return Icons.show_chart;
      case 'account_balance':
        return Icons.account_balance;
      default:
        return Icons.book;
    }
  }

  static Color _colorFromString(String colorName) {
    switch (colorName) {
      case 'primary':
        return const Color(0xFF5D8CFF);
      case 'secondary':
        return const Color(0xFFFF9E7C);
      case 'success':
        return const Color(0xFF37B38A);
      case 'warning':
        return const Color(0xFFF5C24D);
      default:
        return const Color(0xFF5D8CFF);
    }
  }
}

/// Урок раздела обучения.
///
/// `quiz` — необязательный список вопросов из markdown-frontmatter (legacy путь,
/// валидация локальная по `correctIndex`).
/// `serverQuizId` — ID теста на бэке. Если задан, валидация уходит на сервер
/// и результаты возвращаются им же. См. [ServerQuiz].
/// `serverId` — ID самого урока на бэке. Нужен для отметки прохождения.
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
  });

  final String id;
  final String title;
  final String description;
  final String academicDefinition;
  final String imageUrl;
  final String body;
  final int? estimatedMinutes;

  /// Опциональная связка «попробуй вживую» (см. backend Lesson.Practice*).
  /// Если задан [practiceText] — в уроке показывается карточка с deep-link
  /// в рынок (на инструмент [practiceSymbol] или, если он пуст, на список).
  final String? practiceSymbol;
  final String? practiceText;

  /// Опциональная карточка retrieval-practice (см. backend Lesson.Recall*):
  /// вопрос на вспоминание и эталонный ответ для самопроверки.
  final String? recallPrompt;
  final String? recallAnswer;

  /// Глава внутри раздела (необязательно). Группирует уроки под общим
  /// заголовком-главой в дорожке раздела. См. backend Lesson.Group.
  final String? group;

  final List<QuizQuestion> quiz;
  final String? serverId;
  final String? serverQuizId;

  /// Урок отмечен пройденным на бэке (`/me/lessons/...`). Используется
  /// для синхронизации локального прогресса с сервером при загрузке.
  final bool serverCompleted;

  bool get hasQuiz => quiz.isNotEmpty || serverQuizId != null;
  bool get hasServerQuiz => serverQuizId != null;
}

/// Один вопрос мини-теста с одиночным выбором.
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
