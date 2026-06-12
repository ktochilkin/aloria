import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/learning_mode/presentation/order_form_coaching.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Блок «Новая заявка»: выбор вида (рыночная/лимитная/стоп), количество,
/// цены и кнопки «Купить» / «Продать». Для стоп-заявки — цена срабатывания
/// и необязательная лимитная цена (пустая = после срабатывания уйдёт
/// рыночная заявка).
class OrderFormSection extends StatelessWidget {
  const OrderFormSection({
    super.key,
    required this.kind,
    required this.onKindChanged,
    required this.qtyController,
    required this.priceController,
    required this.triggerController,
    required this.stopLimitController,
    required this.stopCondition,
    required this.onStopConditionChanged,
    required this.onSubmit,
    required this.submitting,
    this.currentPrice,
  });

  /// Выбранный вид заявки.
  final OrderFormKind kind;

  /// Смена вида заявки.
  final ValueChanged<OrderFormKind> onKindChanged;

  /// Контроллер поля количества.
  final TextEditingController qtyController;

  /// Контроллер цены лимитной заявки.
  final TextEditingController priceController;

  /// Контроллер цены срабатывания стоп-заявки.
  final TextEditingController triggerController;

  /// Контроллер лимитной цены стоп-заявки (пусто — стоп-маркет).
  final TextEditingController stopLimitController;

  /// Условие срабатывания стоп-заявки (выбирается явно).
  final StopCondition stopCondition;

  /// Смена условия срабатывания.
  final ValueChanged<StopCondition> onStopConditionChanged;

  /// Текущая цена инструмента — для подсказки у поля срабатывания.
  final double? currentPrice;

  /// Отправка заявки указанной стороной.
  final ValueChanged<OrderSide> onSubmit;

  /// Идёт отправка — кнопки заблокированы.
  final bool submitting;

  Widget _conditionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required StopCondition value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = stopCondition == value;
    final down = value == StopCondition.lessOrEqual;
    final accent = down ? AppColors.error : AppColors.success;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? accent : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: accent.withValues(alpha: 0.14),
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: text.bodyMedium?.copyWith(
        color: selected ? accent : scheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? accent : scheme.outline.withValues(alpha: 0.6),
      ),
      onSelected: (_) => onStopConditionChanged(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget kindChip(String label, OrderFormKind value) {
      final selected = kind == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: text.bodyMedium?.copyWith(
          color: selected ? scheme.primary : scheme.onSurface,
        ),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.6),
        ),
        onSelected: (_) => onKindChanged(value),
      );
    }

    InputDecoration field(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        );

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
                  context.push('/learn/first-trade/order_basics'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            kindChip('Рыночная', OrderFormKind.market),
            kindChip('Лимитная', OrderFormKind.limit),
            kindChip('Стоп', OrderFormKind.stop),
          ],
        ),
        OrderTypeHint(kind: kind),
        const SizedBox(height: 12),
        TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          textInputAction: kind == OrderFormKind.market
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: (_) {
            if (kind == OrderFormKind.market) {
              FocusScope.of(context).unfocus();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          decoration: field('Количество'),
        ),
        // Поле цены имеет смысл только для лимитной заявки. Для рыночной
        // прячем его целиком, чтобы не путать неактивным полем.
        if (kind == OrderFormKind.limit) ...[
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: field('Цена'),
          ),
        ],
        if (kind == OrderFormKind.stop) ...[
          const SizedBox(height: 14),
          Text(
            'Сработает, когда цена…',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _conditionChip(
                context,
                label: 'будет меньше, чем',
                icon: Icons.south,
                value: StopCondition.lessOrEqual,
              ),
              _conditionChip(
                context,
                label: 'будет больше, чем',
                icon: Icons.north,
                value: StopCondition.moreOrEqual,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: triggerController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: field(
              'Цена срабатывания',
              hint: currentPrice != null
                  ? 'сейчас ${currentPrice!.toStringAsFixed(2)}'
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: stopLimitController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: field(
              'Лимитная цена (необязательно)',
              hint: 'пусто — исполнится по рынку',
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
