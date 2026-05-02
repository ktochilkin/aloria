import 'dart:math' as math;

import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Прогресс-кольцо. Используется на карточках разделов.
// ---------------------------------------------------------------------------

class SectionProgressRing extends StatelessWidget {
  const SectionProgressRing({
    super.key,
    required this.completed,
    required this.total,
    required this.tint,
    this.size = 56,
    this.strokeWidth = 4,
  });

  final int completed;
  final int total;
  final Color tint;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final isDone = total > 0 && completed == total;
    final fillColor = isDone ? AppColors.success : tint;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction,
          color: fillColor,
          trackColor: scheme.outline.withValues(alpha: 0.5),
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: isDone
              ? Icon(Icons.check, size: size * 0.45, color: AppColors.success)
              : Text(
                  '$completed/$total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Узел дорожки уроков. Слева — статус-кружок и соединительные линии,
// справа — карточка с названием, описанием и метаданными урока.
// ---------------------------------------------------------------------------

enum RoadmapNodeStatus { current, completed, available }

class LessonRoadmapNode extends StatelessWidget {
  const LessonRoadmapNode({
    super.key,
    required this.index,
    required this.lesson,
    required this.tint,
    required this.status,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final int index; // нумерация урока, начиная с 1
  final Lesson lesson;
  final Color tint;
  final RoadmapNodeStatus status;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoadmapRail(
            status: status,
            tint: tint,
            isFirst: isFirst,
            isLast: isLast,
            number: index,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Material(
                color: scheme.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: status == RoadmapNodeStatus.current
                        ? tint.withValues(alpha: 0.7)
                        : scheme.outline,
                    width: status == RoadmapNodeStatus.current ? 1.4 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: status, tint: tint),
                            const Spacer(),
                            if (lesson.estimatedMinutes != null)
                              _MetaChip(
                                icon: Icons.schedule,
                                label: '${lesson.estimatedMinutes} мин',
                              ),
                            if (lesson.hasQuiz) ...[
                              const SizedBox(width: 6),
                              _MetaChip(
                                icon: Icons.task_alt,
                                label: 'Тест',
                                tint: tint,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lesson.title,
                          style: text.titleMedium,
                        ),
                        if (lesson.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            lesson.description,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapRail extends StatelessWidget {
  const _RoadmapRail({
    required this.status,
    required this.tint,
    required this.isFirst,
    required this.isLast,
    required this.number,
  });

  final RoadmapNodeStatus status;
  final Color tint;
  final bool isFirst;
  final bool isLast;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = scheme.outline.withValues(alpha: 0.7);

    final isCompleted = status == RoadmapNodeStatus.completed;
    final isCurrent = status == RoadmapNodeStatus.current;

    final dotBg = isCompleted
        ? AppColors.success
        : isCurrent
            ? tint
            : scheme.surface;
    final dotBorder = isCompleted
        ? AppColors.success
        : isCurrent
            ? tint
            : scheme.outline;
    final dotForeground = isCompleted || isCurrent
        ? Colors.white
        : AppColors.onSurfaceVariant;

    return SizedBox(
      width: 36,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: isFirst ? Colors.transparent : lineColor,
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: dotBg,
              shape: BoxShape.circle,
              border: Border.all(color: dotBorder, width: 1.5),
            ),
            alignment: Alignment.center,
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: dotForeground,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : lineColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.tint});

  final RoadmapNodeStatus status;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RoadmapNodeStatus.completed => ('Пройдено', AppColors.success),
      RoadmapNodeStatus.current => ('Сейчас', tint),
      RoadmapNodeStatus.available => ('Доступно', AppColors.onSurfaceVariant),
    };
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: text.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.onSurfaceVariant;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Полоса прогресса (для шапки раздела и карточки «Продолжить»).
// ---------------------------------------------------------------------------

class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.fraction,
    required this.tint,
    this.height = 6,
  });

  final double fraction;
  final Color tint;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: scheme.outline.withValues(alpha: 0.4),
        child: LayoutBuilder(
          builder: (context, c) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: c.maxWidth * clamped,
                height: height,
                decoration: BoxDecoration(
                  color: clamped == 1.0 ? AppColors.success : tint,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
