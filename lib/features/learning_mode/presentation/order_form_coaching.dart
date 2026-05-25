import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Подсказка в момент действия для формы заявки.
///
/// Показывается только в режиме обучения (см. [SettingsController.setLearningMode])
/// и следует формату §6.4 «Сейчас ты делаешь X. Это значит Y». Текст
/// адаптируется под выбранный тип заявки — рыночную или лимитную, — поэтому
/// не превращается в один и тот же баннер, который мозг учится игнорировать.
class OrderTypeHint extends ConsumerWidget {
  const OrderTypeHint({super.key, required this.isLimit});

  final bool isLimit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningMode = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    if (!learningMode) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final body = isLimit
        ? 'Сейчас ты выставляешь **лимитную заявку**. Это значит: сделка '
            'произойдёт, только если в стакане найдётся встречная по твоей цене '
            'или лучше. Укажи цену, по которой готов купить или продать, — '
            'и заявка может ждать в стакане или вовсе не исполниться.'
        : 'Сейчас ты выставляешь **рыночную заявку**. Это значит: покупка или '
            'продажа произойдёт сразу по лучшей доступной цене в стакане. '
            'Быстро — но цена может оказаться не той, что ты видишь сейчас.';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: MarkdownBody(
              data: body,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: text.bodySmall?.copyWith(height: 1.45),
                strong: text.bodySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Человеческое объяснение, почему заявку отклонили (§6.3).
///
/// [brokerMessage] — техническое сообщение биржи/симулятора, если оно есть
/// (синхронная ошибка отправки или `ClientOrder.comment`). Конкретную причину
/// не выдумываем: показываем частые причины человеческим языком, а сообщение
/// биржи — отдельно и приглушённо.
Future<void> showOrderRejectionHelp(
  BuildContext context, {
  String? brokerMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _RejectionSheet(brokerMessage: brokerMessage),
  );
}

class _RejectionSheet extends StatelessWidget {
  const _RejectionSheet({this.brokerMessage});

  final String? brokerMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final message = brokerMessage?.trim();

    return SafeArea(
      child: Padding(
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.info_outline, color: scheme.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Почему заявку отклонили',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
              'Заявка не прошла — и это нормальная часть обучения, ничего не '
              'сломалось. Чаще всего причина одна из:',
              style: text.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 10),
            const _Reason(
              text: 'Не хватает покупательной способности на этот объём по '
                  'этой цене.',
            ),
            const _Reason(
              text: 'Цена лимитной заявки вне допустимого шага или слишком '
                  'далеко от рынка.',
            ),
            const _Reason(
              text: 'Инструмент сейчас не торгуется или сессия закрыта.',
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Сообщение биржи: $message',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/learn/trading-basics/buying_power');
                },
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('Урок «Покупательная способность»'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
