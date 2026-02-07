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
      lessons: [], // lessons will be loaded separately
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
      default:
        return Icons.book;
    }
  }

  static Color _colorFromString(String colorName) {
    switch (colorName) {
      case 'primary':
        return const Color(0xFF6750A4);
      case 'success':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF6750A4);
    }
  }
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.academicDefinition,
    required this.imageUrl,
    required this.body,
  });

  final String id;
  final String title;
  final String description;
  final String academicDefinition;
  final String imageUrl;
  final String body;
}
