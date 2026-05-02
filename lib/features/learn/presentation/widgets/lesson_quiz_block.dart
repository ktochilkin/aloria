import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learn/domain/models.dart';
import 'package:flutter/material.dart';

/// Интерактивный блок мини-теста, который показывается в конце урока.
///
/// Поведение:
/// - Тест не блокирует продвижение по курсу: пользователь может ответить
///   сейчас, изменить ответы, либо вообще пропустить блок.
/// - После выбора варианта показывается, верный он или нет, плюс пояснение.
/// - Когда пройдены все вопросы, в коллбек `onCompleted` уходит итог
///   (число правильных ответов и общее количество). Виджет вызывает его
///   ровно один раз для текущего набора ответов.
class LessonQuizBlock extends StatefulWidget {
  const LessonQuizBlock({
    super.key,
    required this.questions,
    required this.tint,
    this.initialAnswers,
    this.onCompleted,
  });

  final List<QuizQuestion> questions;
  final Color tint;

  /// Сохранённые ответы (для случая, когда пользователь возвращается к уроку).
  /// Длина списка должна совпадать с `questions.length`. Значение -1 = нет ответа.
  final List<int>? initialAnswers;

  /// Вызывается, когда пользователь ответил на все вопросы.
  /// `score` — число правильных, `total` — общее число вопросов.
  final void Function(int score, int total)? onCompleted;

  @override
  State<LessonQuizBlock> createState() => _LessonQuizBlockState();
}

class _LessonQuizBlockState extends State<LessonQuizBlock> {
  late List<int> _answers;
  bool _completedReported = false;

  @override
  void initState() {
    super.initState();
    _answers = List<int>.filled(widget.questions.length, -1);
    final initial = widget.initialAnswers;
    if (initial != null && initial.length == widget.questions.length) {
      for (var i = 0; i < initial.length; i++) {
        _answers[i] = initial[i];
      }
      _maybeReportCompletion();
    }
  }

  void _onAnswerSelected(int qIndex, int optIndex) {
    if (_answers[qIndex] != -1) return; // ответ можно дать только один раз
    setState(() {
      _answers[qIndex] = optIndex;
    });
    _maybeReportCompletion();
  }

  void _maybeReportCompletion() {
    if (_completedReported) return;
    final allAnswered = !_answers.contains(-1);
    if (!allAnswered) return;
    _completedReported = true;
    final score = _calculateScore();
    widget.onCompleted?.call(score, widget.questions.length);
  }

  int _calculateScore() {
    var score = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      if (_answers[i] == widget.questions[i].correctIndex) score++;
    }
    return score;
  }

  void _resetQuiz() {
    setState(() {
      _answers = List<int>.filled(widget.questions.length, -1);
      _completedReported = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final allAnswered = !_answers.contains(-1);
    final score = _calculateScore();

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
              Text('Проверь себя', style: text.titleMedium),
              const Spacer(),
              Text(
                '${widget.questions.length} ${_questionWord(widget.questions.length)}',
                style: text.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Короткая самопроверка. На результат прохождения курса не влияет — '
            'вернуться и переответить можно в любой момент.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ...List.generate(widget.questions.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == widget.questions.length - 1 ? 0 : 14,
              ),
              child: _QuestionCard(
                index: i + 1,
                question: widget.questions[i],
                selected: _answers[i],
                tint: widget.tint,
                onSelect: (optIndex) => _onAnswerSelected(i, optIndex),
              ),
            );
          }),
          if (allAnswered) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (score == widget.questions.length
                        ? AppColors.success
                        : widget.tint)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    score == widget.questions.length
                        ? Icons.check_circle
                        : Icons.replay_circle_filled,
                    color: score == widget.questions.length
                        ? AppColors.success
                        : widget.tint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      score == widget.questions.length
                          ? 'Все ответы верные.'
                          : 'Правильных ответов: $score из ${widget.questions.length}.',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetQuiz,
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.tint,
    required this.onSelect,
  });

  final int index;
  final QuizQuestion question;
  final int selected;
  final Color tint;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final answered = selected != -1;

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
              child: Text(question.question, style: text.bodyLarge),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(question.options.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _OptionTile(
              text: question.options[i],
              isCorrect: i == question.correctIndex,
              isSelected: selected == i,
              answered: answered,
              tint: tint,
              onTap: () => onSelect(i),
            ),
          );
        }),
        if (answered && question.explanation != null && question.explanation!.isNotEmpty) ...[
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
                Icon(Icons.info_outline,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.explanation!,
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
    required this.isCorrect,
    required this.isSelected,
    required this.answered,
    required this.tint,
    required this.onTap,
  });

  final String text;
  final bool isCorrect;
  final bool isSelected;
  final bool answered;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color background = scheme.surface;
    Color border = scheme.outline;
    Color textColor = AppColors.onSurface;
    IconData? trailing;
    Color trailingColor = scheme.onSurfaceVariant;

    if (answered) {
      if (isCorrect) {
        background = AppColors.success.withValues(alpha: 0.10);
        border = AppColors.success;
        textColor = AppColors.onSurface;
        trailing = Icons.check_circle;
        trailingColor = AppColors.success;
      } else if (isSelected) {
        background = AppColors.error.withValues(alpha: 0.10);
        border = AppColors.error;
        textColor = AppColors.onSurface;
        trailing = Icons.cancel;
        trailingColor = AppColors.error;
      } else {
        background = scheme.surface;
        border = scheme.outline.withValues(alpha: 0.5);
        textColor = scheme.onSurfaceVariant;
      }
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: answered ? null : onTap,
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
              ] else if (!answered) ...[
                const SizedBox(width: 8),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.outline),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
