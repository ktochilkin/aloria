import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/state_placeholder.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/presentation/widgets/server_quiz_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Краткая карточка top-up теста из /api/v1/learning/top-up-quizzes.
class _TopUpQuizSummary {
  const _TopUpQuizSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardBuyingPower,
    required this.questionCount,
  });

  final String id;
  final String title;
  final String description;
  final double rewardBuyingPower;
  final int questionCount;

  factory _TopUpQuizSummary.fromJson(Map<String, dynamic> json) {
    return _TopUpQuizSummary(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rewardBuyingPower: (json['rewardBuyingPower'] as num?)?.toDouble() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

final _topUpQuizzesProvider =
    FutureProvider<List<_TopUpQuizSummary>>((ref) async {
  final client = ref.watch(learningApiClientProvider);
  final raw = await client.fetchTopUpQuizzes();
  return raw.map(_TopUpQuizSummary.fromJson).toList(growable: false);
});

/// Экран «Расширить доступ»: список top-up тестов, каждый пройденный тест
/// увеличивает покупательную способность.
class TopUpPage extends ConsumerWidget {
  const TopUpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final list = ref.watch(_topUpQuizzesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расширить доступ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(_topUpQuizzesProvider);
          await ref.read(_topUpQuizzesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подтвердите знания',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Каждый пройденный тест увеличивает покупательную способность. '
                    'Это мера допуска: чем уверенней понимаете рынок — тем больше операций открыто.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            list.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: StatePlaceholder(
                  icon: Icons.cloud_off_outlined,
                  title: 'Не получилось загрузить тесты',
                  message: 'Проверь соединение и попробуй ещё раз.',
                  actionLabel: 'Обновить',
                  onAction: () => ref.invalidate(_topUpQuizzesProvider),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: StatePlaceholder(
                        icon: Icons.school_outlined,
                        title: 'Новых тестов пока нет',
                        message: 'Они появляются по мере прохождения уроков — '
                            'загляни сюда позже.',
                      ),
                    )
                  : Column(
                      children: [
                        for (final q in items) _TopUpQuizCard(quiz: q),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUpQuizCard extends StatelessWidget {
  const _TopUpQuizCard({required this.quiz});

  final _TopUpQuizSummary quiz;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) =>
                    _TopUpQuizPage(quizId: quiz.id, title: quiz.title),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.palette.heroBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quiz.title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (quiz.rewardBuyingPower > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+${quiz.rewardBuyingPower.toStringAsFixed(0)} ₽',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                if (quiz.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    quiz.description,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.help_outline,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${quiz.questionCount} ${_questionWord(quiz.questionCount)}',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _questionWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'вопрос';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'вопроса';
    }
    return 'вопросов';
  }
}

class _TopUpQuizPage extends ConsumerWidget {
  const _TopUpQuizPage({required this.quizId, required this.title});

  final String quizId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ServerQuizBlock(
            quizId: quizId,
            tint: AppColors.primary,
            onPassed: (_) {},
          ),
        ],
      ),
    );
  }
}
