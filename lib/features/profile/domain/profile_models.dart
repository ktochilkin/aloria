import 'package:flutter/material.dart';

class UserProgress {
  const UserProgress({
    required this.streakDays,
    required this.lessonsCompleted,
    required this.quizzesPassed,
    required this.bonusBuyingPower,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
  });

  final int streakDays;
  final int lessonsCompleted;
  final int quizzesPassed;
  final double bonusBuyingPower;
  final int achievementsUnlocked;
  final int achievementsTotal;

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      lessonsCompleted: (json['lessonsCompleted'] as num?)?.toInt() ?? 0,
      quizzesPassed: (json['quizzesPassed'] as num?)?.toInt() ?? 0,
      bonusBuyingPower: (json['bonusBuyingPower'] as num?)?.toDouble() ?? 0,
      achievementsUnlocked: (json['achievementsUnlocked'] as num?)?.toInt() ?? 0,
      achievementsTotal: (json['achievementsTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

class Achievement {
  const Achievement({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.iconName,
    required this.rewardBuyingPower,
    required this.isUnlocked,
    required this.unlockedAt,
    required this.progress,
    required this.threshold,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String iconName;
  final double rewardBuyingPower;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int? progress;
  final int? threshold;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    DateTime? unlocked;
    final raw = json['unlockedAt'];
    if (raw is String && raw.isNotEmpty) {
      unlocked = DateTime.tryParse(raw);
    }
    return Achievement(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'emoji_events',
      rewardBuyingPower:
          (json['rewardBuyingPower'] as num?)?.toDouble() ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: unlocked,
      progress: (json['progress'] as num?)?.toInt(),
      threshold: (json['threshold'] as num?)?.toInt(),
    );
  }

  /// Сколько процентов прогресса к разблокировке (0..1).
  /// `null` — у ачивки нет порога (например, «первая позиция»).
  double? get progressFraction {
    if (isUnlocked) return 1.0;
    final t = threshold ?? 0;
    if (t <= 0) return null;
    final p = progress ?? 0;
    return (p / t).clamp(0.0, 1.0);
  }

  /// Маппинг строкового имени иконки в Material Icons.
  IconData get icon => _iconFromName(iconName);

  static IconData _iconFromName(String name) {
    switch (name) {
      case 'menu_book':
        return Icons.menu_book;
      case 'auto_stories':
        return Icons.auto_stories;
      case 'fact_check':
        return Icons.fact_check;
      case 'school':
        return Icons.school;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'trending_up':
        return Icons.trending_up;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'task_alt':
        return Icons.task_alt;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'star':
        return Icons.star;
      case 'verified':
        return Icons.verified;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.emoji_events;
    }
  }
}
