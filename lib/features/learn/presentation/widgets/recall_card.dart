import 'package:aloria/core/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Карточка retrieval-practice: вопрос на вспоминание, затем самопроверка.
///
/// Книга Дирксен: вспоминание (recall) тренирует память сильнее, чем узнавание.
/// Сценарий: прочитал вопрос → попытался вспомнить → «Показать ответ» →
/// честно оценил себя. Оценка уходит в [onGrade] (бэкенд планирует повтор по
/// SM-2). Виджет переиспользуется на экране урока и в сессии повторения.
class RecallCard extends StatefulWidget {
  const RecallCard({
    super.key,
    required this.prompt,
    required this.answer,
    required this.tint,
    required this.onGrade,
  });

  final String prompt;
  final String? answer;
  final Color tint;

  /// Возвращает интервал в днях до следующего повторения (если бэкенд вернул).
  final Future<int?> Function(bool remembered) onGrade;

  @override
  State<RecallCard> createState() => _RecallCardState();
}

class _RecallCardState extends State<RecallCard> {
  bool _revealed = false;
  bool _grading = false;
  String? _doneText;

  Future<void> _grade(bool remembered) async {
    if (_grading) return;
    setState(() => _grading = true);
    int? days;
    try {
      days = await widget.onGrade(remembered);
    } catch (_) {
      // best-effort: не валим UI, просто покажем нейтральное подтверждение.
    }
    if (!mounted) return;
    setState(() {
      _grading = false;
      _doneText = remembered
          ? (days != null
              ? 'Отмечено. Вернёмся к этому примерно через $days дн.'
              : 'Отмечено. Вернёмся к этому позже.')
          : 'Хорошо, что проверил. Повторим уже завтра.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.tint.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_outlined, color: widget.tint, size: 20),
              const SizedBox(width: 8),
              Text(
                'Проверь себя',
                style: t.labelLarge?.copyWith(
                  color: widget.tint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.prompt, style: t.bodyLarge?.copyWith(height: 1.45)),
          if (_doneText != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _doneText!,
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!_revealed) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Показать ответ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: scheme.outline),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.tint.withValues(alpha: 0.25)),
              ),
              child: Text(
                widget.answer?.trim().isNotEmpty == true
                    ? widget.answer!.trim()
                    : 'Сверь с тем, что помнишь из урока.',
                style: t.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _grading ? null : () => _grade(true),
                    style: FilledButton.styleFrom(backgroundColor: widget.tint),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Вспомнил'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _grading ? null : () => _grade(false),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Не совсем'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: scheme.outline),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
