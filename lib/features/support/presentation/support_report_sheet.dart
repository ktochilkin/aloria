import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/support/data/support_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Открывает шторку «Сообщить в поддержку».
///
/// Технический контекст (ошибка, покупательная способность, позиции)
/// собирается автоматически — пользователю остаётся при желании описать
/// проблему своими словами и нажать «Отправить».
Future<void> showSupportReportSheet(
  BuildContext context, {
  required String subject,
  String? errorCode,
  String? errorMessage,
  Map<String, dynamic>? extraContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      // Поднимаем содержимое над клавиатурой, когда открыто поле комментария.
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SupportReportSheet(
        subject: subject,
        errorCode: errorCode,
        errorMessage: errorMessage,
        extraContext: extraContext,
      ),
    ),
  );
}

/// Содержимое шторки обращения в поддержку.
class SupportReportSheet extends ConsumerStatefulWidget {
  const SupportReportSheet({
    super.key,
    required this.subject,
    this.errorCode,
    this.errorMessage,
    this.extraContext,
  });

  /// Тема обращения (например, «Не отправилась заявка по SBER»).
  final String subject;
  final String? errorCode;
  final String? errorMessage;

  /// Дополнительный контекст (параметры заявки и т.п.).
  final Map<String, dynamic>? extraContext;

  @override
  ConsumerState<SupportReportSheet> createState() => _SupportReportSheetState();
}

class _SupportReportSheetState extends ConsumerState<SupportReportSheet> {
  final _commentController = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _sendError;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Снимок состояния для разбора: ошибка, деньги, позиции, платформа.
  Map<String, dynamic> _collectContext() {
    final summary = ref.read(portfolioSummaryProvider).valueOrNull;
    final positions = ref.read(positionsProvider).valueOrNull;
    return {
      ...?widget.extraContext,
      if (summary != null) 'buyingPower': summary.buyingPower,
      if (positions != null)
        'positions': [
          for (final p in positions)
            {
              'symbol': p.symbol,
              'qty': p.qtyUnits ?? p.quantity,
              'avgPrice': p.averagePrice,
              'currentVolume': p.currentVolume,
            },
        ],
      'platform': defaultTargetPlatform.name,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.createTicket(
        subject: widget.subject,
        errorCode: widget.errorCode,
        errorMessage: widget.errorMessage,
        context: _collectContext(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      ref.invalidate(supportTicketsProvider);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sendError =
              'Не получилось отправить. Проверь соединение и попробуй ещё раз.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_sent) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Обращение отправлено',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Мы разберёмся, что пошло не так. Ответ придёт на почту, '
              'а статус обращения можно посмотреть в настройках — '
              'раздел «Мои обращения».',
              style: text.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Понятно'),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Сообщить в поддержку',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'К обращению автоматически приложатся технические детали: '
              'что за ошибка и в каком состоянии был портфель. '
              'Так мы разберёмся быстрее. Ответ придёт на почту.',
              style: text.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Тема: ${widget.subject}',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Своими словами (необязательно)',
                hintText: 'Что ты делал, когда это случилось?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            if (_sendError != null) ...[
              const SizedBox(height: 8),
              Text(
                _sendError!,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send, size: 18),
                label: Text(_sending ? 'Отправка…' : 'Отправить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
