import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Подсказка в момент действия для формы заявки.
///
/// Показывается только в режиме обучения (см. [SettingsController.setLearningMode])
/// и следует формату §6.4 «Сейчас ты делаешь X. Это значит Y». Текст
/// адаптируется под выбранный тип заявки — рыночную или лимитную, — поэтому
/// не превращается в один и тот же баннер, который мозг учится игнорировать.
class OrderTypeHint extends ConsumerWidget {
  const OrderTypeHint({super.key, required this.kind});

  final OrderFormKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningMode = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    if (!learningMode) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final body = switch (kind) {
      OrderFormKind.limit =>
        'Сейчас ты выставляешь **лимитную заявку**. Это значит: сделка '
            'произойдёт, только если в стакане найдётся встречная по твоей цене '
            'или лучше. Укажи цену, по которой готов купить или продать, — '
            'и заявка может ждать в стакане или вовсе не исполниться.',
      OrderFormKind.stop =>
        'Сейчас ты выставляешь **стоп-заявку**. Это значит: она ждёт, пока '
            'цена дойдёт до цены срабатывания, и только тогда отправит заявку '
            'на биржу. Так ограничивают убыток или фиксируют прибыль заранее, '
            'не следя за рынком.',
      OrderFormKind.market =>
        'Сейчас ты выставляешь **рыночную заявку**. Это значит: покупка или '
            'продажа произойдёт сразу по лучшей доступной цене в стакане. '
            'Быстро — но цена может оказаться не той, что ты видишь сейчас.',
    };

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
