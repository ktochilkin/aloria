import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/market/application/stop_orders_provider.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/positions/widgets/stop_order_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Плитка условной (стоп) заявки: ждёт цену срабатывания, после чего
/// выставит рыночную или лимитную заявку. Тап открывает шторку с деталями.
class StopOrderTile extends ConsumerWidget {
  const StopOrderTile({super.key, required this.order});

  /// Условная заявка.
  final StopOrder order;

  String _conditionLabel() {
    final price = order.stopPrice?.toStringAsFixed(2) ?? '—';
    return switch (order.condition) {
      StopCondition.more || StopCondition.moreOrEqual => 'цена ≥ $price',
      StopCondition.less || StopCondition.lessOrEqual => 'цена ≤ $price',
    };
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить стоп-заявку?'),
        content: Text(
          'Условная заявка по ${order.symbol} перестанет ждать цену '
          'срабатывания.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final cancel = ref.read(cancelStopOrderProvider);
      await cancel(
        orderId: order.id,
        portfolio: order.portfolio,
        exchange: order.exchange,
      );
      if (context.mounted) {
        showTopNotification(context, 'Стоп-заявка отменена');
      }
    } catch (e) {
      if (context.mounted) {
        showTopNotification(context, 'Ошибка отмены: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sideLabel = order.side == OrderSide.buy ? 'Покупка' : 'Продажа';
    final typeLabel = order.isStopLimit ? 'Стоп-лимит' : 'Стоп-маркет';

    return AppListTile(
      onTap: () => showStopOrderDetails(context, order),
      title: order.symbol,
      subtitleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                'Сработает: ${_conditionLabel()}',
                style: text.labelMedium?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$sideLabel · $typeLabel',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: Container(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(
              TextSpan(
                style: text.bodySmall,
                children: [
                  const TextSpan(text: 'Объём: '),
                  TextSpan(
                    text: '${order.qty ?? '—'}',
                    style: monoNum(size: 12, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (order.isStopLimit && order.price != null) ...[
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: text.bodySmall,
                  children: [
                    const TextSpan(text: 'Лимит: '),
                    TextSpan(
                      text: order.price!.toStringAsFixed(2),
                      style: monoNum(size: 12, weight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            if (order.isActive) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _cancel(context, ref),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppColors.error, width: 1.2),
                  foregroundColor: AppColors.error,
                ),
                child: const Text(
                  'Отменить',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      isThreeLine: true,
      topAlignTrailing: true,
    );
  }
}
