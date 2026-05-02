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
/// `quiz` — необязательный список вопросов для самопроверки в конце урока.
/// Тест не блокирует прохождение: пользователь может пропустить его.
/// `estimatedMinutes` — приблизительное время чтения, отображается в шапке урока.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.academicDefinition,
    required this.imageUrl,
    required this.body,
    this.estimatedMinutes,
    this.quiz = const [],
  });

  final String id;
  final String title;
  final String description;
  final String academicDefinition;
  final String imageUrl;
  final String body;
  final int? estimatedMinutes;
  final List<QuizQuestion> quiz;

  bool get hasQuiz => quiz.isNotEmpty;
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
