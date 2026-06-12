import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learning_mode/presentation/order_form_coaching.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Блок «Новая заявка»: выбор типа (рыночная/лимитная), количество,
/// цена для лимитной и кнопки «Купить» / «Продать».
class OrderFormSection extends StatelessWidget {
  const OrderFormSection({
    super.key,
    required this.isLimit,
    required this.onToggleType,
    required this.qtyController,
    required this.priceController,
    required this.onSubmit,
    required this.submitting,
  });

  /// Выбран лимитный тип заявки.
  final bool isLimit;

  /// Переключение типа заявки (true — лимитная).
  final ValueChanged<bool> onToggleType;

  /// Контроллер поля количества.
  final TextEditingController qtyController;

  /// Контроллер поля цены (для лимитной).
  final TextEditingController priceController;

  /// Отправка заявки указанной стороной.
  final ValueChanged<OrderSide> onSubmit;

  /// Идёт отправка — кнопки заблокированы.
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Выравнивание повторяет родительскую колонку TradeBody (start),
    // чтобы вынос секции не менял раскладку.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Новая заявка', style: text.titleMedium),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.help_outline, size: 20),
              tooltip: 'Что такое заявка?',
              onPressed: () =>
                  context.push('/learn/trading-basics/orderbook'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Рыночная'),
              selected: !isLimit,
              selectedColor: scheme.primary.withValues(alpha: 0.18),
              backgroundColor: scheme.surfaceContainerHighest,
              labelStyle: text.bodyMedium?.copyWith(
                color: !isLimit ? scheme.primary : scheme.onSurface,
              ),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.6),
              ),
              onSelected: (v) => onToggleType(false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Лимитная'),
              selected: isLimit,
              selectedColor: scheme.primary.withValues(alpha: 0.18),
              backgroundColor: scheme.surfaceContainerHighest,
              labelStyle: text.bodyMedium?.copyWith(
                color: isLimit ? scheme.primary : scheme.onSurface,
              ),
              side: BorderSide(
                color: scheme.outline.withValues(alpha: 0.6),
              ),
              onSelected: (v) => onToggleType(true),
            ),
          ],
        ),
        OrderTypeHint(isLimit: isLimit),
        const SizedBox(height: 12),
        TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (isLimit) {
              FocusScope.of(context).nextFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          decoration: const InputDecoration(
            labelText: 'Количество',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        // Поле цены имеет смысл только для лимитной заявки. Для рыночной
        // прячем его целиком, чтобы не путать неактивным полем.
        if (isLimit) ...[
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: 'Цена',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () => onSubmit(OrderSide.buy),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.shopping_cart_checkout),
                label: submitting
                    ? const Text('Отправка...')
                    : const Text('Купить'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () => onSubmit(OrderSide.sell),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.sell),
                label: submitting
                    ? const Text('Отправка...')
                    : const Text('Продать'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
