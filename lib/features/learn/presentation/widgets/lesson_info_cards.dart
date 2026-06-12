import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Блок академического определения — выделенная карточка с заголовком
/// и формальным текстом определения.
class LessonDefinitionBlock extends StatelessWidget {
  const LessonDefinitionBlock({
    super.key,
    required this.title,
    required this.content,
    required this.tint,
  });

  /// Заголовок блока (обычно «Академическое определение»).
  final String title;

  /// Текст определения.
  final String content;

  /// Акцент раздела.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                title,
                style: text.labelMedium?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: text.bodyMedium),
        ],
      ),
    );
  }
}

/// Карточка «Попробуй вживую» — deep-link из урока в рынок (на конкретный
/// инструмент, если задан practice-символ).
class LessonPracticeCard extends StatelessWidget {
  const LessonPracticeCard({
    super.key,
    required this.tint,
    required this.text,
    this.symbol,
  });

  /// Акцент раздела.
  final Color tint;

  /// Текст задания.
  final String text;

  /// Тикер инструмента для перехода (опционально).
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: tint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Попробуй вживую',
                style: t.labelLarge?.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: t.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final s = symbol?.trim() ?? '';
                context.push(s.isNotEmpty ? '/market/$s' : '/market');
              },
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.show_chart, size: 18),
              label: const Text('Открыть рынок'),
            ),
          ),
        ],
      ),
    );
  }
}
