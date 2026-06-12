import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:aloria/features/learn/presentation/widgets/learning_widgets.dart';
import 'package:flutter/material.dart';

/// Шапка позиции урока в разделе: бейдж «Урок i из N», оценка времени,
/// отметка «Пройдено» и тонкий прогресс-бар по разделу.
class LessonProgressHeader extends StatelessWidget {
  const LessonProgressHeader({
    super.key,
    required this.section,
    required this.index,
    required this.total,
    required this.estimatedMinutes,
    required this.isRead,
  });

  /// Раздел, которому принадлежит урок (источник акцента).
  final LearningSection section;

  /// Индекс урока в разделе (с нуля).
  final int index;

  /// Всего уроков в разделе.
  final int total;

  /// Оценка времени чтения в минутах (опционально).
  final int? estimatedMinutes;

  /// Прочитан ли урок.
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: section.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Урок ${index + 1} из $total',
                style: text.labelMedium?.copyWith(
                  color: section.tint,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (estimatedMinutes != null) ...[
              Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '$estimatedMinutes мин',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const Spacer(),
            if (isRead)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Пройдено',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        ThinProgressBar(
          fraction: (index + 1) / total,
          tint: section.tint,
          height: 4,
        ),
      ],
    );
  }
}

/// Бейдж «Главное задание этапа» — показывается над заголовком
/// capstone-урока.
class LessonCapstoneBadge extends StatelessWidget {
  const LessonCapstoneBadge({super.key, required this.tint});

  /// Акцент раздела.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: tint),
          const SizedBox(width: 4),
          Text(
            'Главное задание этапа',
            style: text.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
