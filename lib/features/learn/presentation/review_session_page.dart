import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/application/review_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/presentation/widgets/recall_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сессия разнесённого повторения: листаем карточки recall, которые пора
/// повторить, одну за другой. Оценка уходит на бэкенд (планирует следующий срок).
class ReviewSessionPage extends ConsumerStatefulWidget {
  const ReviewSessionPage({super.key, required this.items});

  final List<DueReview> items;

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  int _index = 0;

  Future<int?> _grade(DueReview item, bool remembered) async {
    final client = ref.read(learningApiClientProvider);
    final portfolioId = ref.read(aloriaPortfolioIdProvider);
    int? days;
    try {
      days = await client.gradeReview(
        lessonId: item.lessonId,
        remembered: remembered,
        portfolioId: portfolioId,
      );
    } catch (_) {
      // best-effort — даже если оценка не дошла, листаем дальше.
    }
    // Даём увидеть подтверждение, затем — к следующей карточке.
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _index += 1);
    });
    return days;
  }

  void _finish() {
    ref.invalidate(dueReviewsProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = widget.items.length;
    final done = _index >= total;

    return Scaffold(
      appBar: AppBar(title: const Text('Повторение')),
      body: done
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task_alt,
                        size: 56, color: AppColors.success),
                    const SizedBox(height: 16),
                    Text('На сегодня всё', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Карточки повторены. Мы напомним о них снова, когда '
                      'придёт время — так знания держатся дольше.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _finish,
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, context.bottomNavBarPadding),
              children: [
                Text(
                  'Карточка ${_index + 1} из $total',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                RecallCard(
                  key: ValueKey(widget.items[_index].lessonId),
                  prompt: widget.items[_index].recallPrompt,
                  answer: widget.items[_index].recallAnswer,
                  tint: AppColors.primary,
                  onGrade: (remembered) =>
                      _grade(widget.items[_index], remembered),
                ),
              ],
            ),
    );
  }
}
