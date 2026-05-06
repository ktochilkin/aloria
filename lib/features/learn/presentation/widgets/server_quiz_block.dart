import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learn/domain/server_quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Тест с серверной валидацией.
///
/// UX:
///   1. Пользователь отвечает на все вопросы (single/multiple choice).
///   2. Жмёт «Проверить ответы».
///   3. Ответы уходят на /api/v1/quizzes/:id/attempts с Idempotency-Key.
///   4. Сервер возвращает результат с правильными опциями и пояснением.
///   5. Виджет рендерит правильность инлайн.
///
/// «Заново» сбрасывает выборы и генерирует новый Idempotency-Key, так что
/// пользователь может перепройти. Награда выдаётся ровно один раз — это
/// гарантирует уникальность ключа на стороне бэка.
class ServerQuizBlock extends ConsumerStatefulWidget {
  const ServerQuizBlock({
    super.key,
    required this.quizId,
    required this.tint,
    this.onPassed,
  });

  final String quizId;
  final Color tint;

  /// Зовётся, когда сервер вернул isPassed=true. Можно использовать
  /// для локальной отметки прогресса/тоста.
  final void Function(QuizAttemptResult result)? onPassed;

  @override
  ConsumerState<ServerQuizBlock> createState() => _ServerQuizBlockState();
}

class _ServerQuizBlockState extends ConsumerState<ServerQuizBlock> {
  ServerQuiz? _quiz;
  Object? _loadError;
  bool _loading = true;

  /// questionId → выбранные optionIds.
  final Map<String, Set<String>> _picks = {};
  QuizAttemptResult? _result;
  bool _submitting = false;
  Object? _submitError;
  String _idemKey = _newKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _newKey() =>
      'quiz-${DateTime.now().microsecondsSinceEpoch}-${UniqueKey()}';

  Future<void> _load() async {
    final client = ref.read(learningApiClientProvider);
    try {
      final raw = await client.fetchQuiz(widget.quizId);
      if (!mounted) return;
      setState(() {
        _quiz = ServerQuiz.fromJson(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  bool _allAnswered(ServerQuiz quiz) {
    for (final q in quiz.questions) {
      final picked = _picks[q.id] ?? const <String>{};
      if (picked.isEmpty) return false;
    }
    return true;
  }

  void _toggle(ServerQuizQuestion q, String optionId) {
    if (_result != null) return; // ответы видны, изменить нельзя
    final current = _picks[q.id] ?? <String>{};
    final next = Set<String>.from(current);
    if (q.allowsMultiple) {
      if (next.contains(optionId)) {
        next.remove(optionId);
      } else {
        next.add(optionId);
      }
    } else {
      next
        ..clear()
        ..add(optionId);
    }
    setState(() {
      _picks[q.id] = next;
    });
  }

  Future<void> _submit() async {
    final quiz = _quiz;
    if (quiz == null || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final client = ref.read(learningApiClientProvider);
      final portfolioId = ref.read(aloriaPortfolioIdProvider);
      final answers = quiz.questions
          .map((q) => {
                'questionId': q.id,
                'selectedOptionIds':
                    (_picks[q.id] ?? const <String>{}).toList(),
              })
          .toList();
      final raw = await client.submitQuizAttempt(
        quizId: quiz.id,
        portfolioId: portfolioId,
        answers: answers,
        idempotencyKey: _idemKey,
      );
      final result = QuizAttemptResult.fromJson(raw);
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
      if (result.isPassed) widget.onPassed?.call(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e;
        _submitting = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _picks.clear();
      _result = null;
      _submitError = null;
      _idemKey = _newKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.tint.withValues(alpha: 0.45)),
        ),
        child: const Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_loadError != null || _quiz == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
        ),
        child: Text('Не удалось загрузить тест: $_loadError',
            style: text.bodyMedium?.copyWith(color: scheme.error)),
      );
    }

    final quiz = _quiz!;
    final allAnswered = _allAnswered(quiz);
    final result = _result;
    final correctIdsByQ = <String, Set<String>>{
      for (final q in result?.questions ?? const <QuestionResult>[])
        q.questionId: q.correctOptionIds.toSet(),
    };
    final qCorrectByQ = <String, bool>{
      for (final q in result?.questions ?? const <QuestionResult>[])
        q.questionId: q.isCorrect,
    };
    final explanationByQ = <String, String?>{
      for (final q in result?.questions ?? const <QuestionResult>[])
        q.questionId: q.explanation,
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.tint.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt, color: widget.tint, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  quiz.title.isEmpty ? 'Проверь себя' : quiz.title,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (quiz.rewardBuyingPower > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+${quiz.rewardBuyingPower.toStringAsFixed(0)} ₽',
                    style: text.labelMedium?.copyWith(
                      color: widget.tint,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (quiz.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              quiz.description,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          ...List.generate(quiz.questions.length, (i) {
            final q = quiz.questions[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == quiz.questions.length - 1 ? 0 : 14,
              ),
              child: _QuestionCard(
                index: i + 1,
                question: q,
                picks: _picks[q.id] ?? const <String>{},
                tint: widget.tint,
                graded: result != null,
                correctIds: correctIdsByQ[q.id] ?? const <String>{},
                isQuestionCorrect: qCorrectByQ[q.id],
                explanation: explanationByQ[q.id],
                onSelect: (optId) => _toggle(q, optId),
              ),
            );
          }),
          const SizedBox(height: 16),
          if (result == null) ...[
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Не получилось отправить: $_submitError',
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    !allAnswered || _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.tint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        allAnswered
                            ? 'Проверить ответы'
                            : 'Ответьте на все вопросы',
                        style: text.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (result.isPassed ? AppColors.success : widget.tint)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    result.isPassed
                        ? Icons.check_circle
                        : Icons.replay_circle_filled,
                    color: result.isPassed ? AppColors.success : widget.tint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.isPassed
                              ? 'Все ответы верные.'
                              : 'Правильных: ${result.correctCount} из ${result.totalQuestions}.',
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (result.isPassed && result.awardedBuyingPower > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'покупательная способность +${result.awardedBuyingPower.toStringAsFixed(0)} ₽',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Заново'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.picks,
    required this.tint,
    required this.graded,
    required this.correctIds,
    required this.isQuestionCorrect,
    required this.explanation,
    required this.onSelect,
  });

  final int index;
  final ServerQuizQuestion question;
  final Set<String> picks;
  final Color tint;
  final bool graded;
  final Set<String> correctIds;
  final bool? isQuestionCorrect;
  final String? explanation;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outline),
              ),
              child: Text(
                '$index',
                style: text.labelMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(question.text, style: text.bodyLarge),
            ),
            if (question.allowsMultiple)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'несколько',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(question.options.length, (i) {
          final opt = question.options[i];
          final isPicked = picks.contains(opt.id);
          final isCorrect = correctIds.contains(opt.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionTile(
              text: opt.text,
              isPicked: isPicked,
              isCorrect: isCorrect,
              graded: graded,
              tint: tint,
              onTap: () => onSelect(opt.id),
            ),
          );
        }),
        if (graded && (explanation?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isQuestionCorrect == true
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.isPicked,
    required this.isCorrect,
    required this.graded,
    required this.tint,
    required this.onTap,
  });

  final String text;
  final bool isPicked;
  final bool isCorrect;
  final bool graded;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color background = scheme.surface;
    Color border = scheme.outline;
    Color textColor = scheme.onSurface;
    IconData? trailing;
    Color trailingColor = scheme.onSurfaceVariant;

    if (graded) {
      if (isCorrect) {
        background = AppColors.success.withValues(alpha: 0.10);
        border = AppColors.success;
        trailing = Icons.check_circle;
        trailingColor = AppColors.success;
      } else if (isPicked) {
        background = AppColors.error.withValues(alpha: 0.10);
        border = AppColors.error;
        trailing = Icons.cancel;
        trailingColor = AppColors.error;
      } else {
        background = scheme.surface;
        border = scheme.outline.withValues(alpha: 0.5);
        textColor = scheme.onSurfaceVariant;
      }
    } else if (isPicked) {
      background = tint.withValues(alpha: 0.08);
      border = tint;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: graded ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Icon(trailing, size: 18, color: trailingColor),
              ] else ...[
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPicked ? tint : Colors.transparent,
                    border: Border.all(
                      color: isPicked ? tint : scheme.outline,
                      width: 2,
                    ),
                  ),
                  child: isPicked
                      ? const Icon(Icons.check,
                          size: 10, color: Colors.white)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
