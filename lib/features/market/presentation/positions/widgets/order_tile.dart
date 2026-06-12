import 'package:aloria/core/theme/components/list_items.dart';
import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Плитка заявки в списке портфеля: статус, сторона/тип/время, объём и
/// цена, кнопка отмены для активных. Тап открывает инструмент в «Рынке».
class OrderTile extends ConsumerWidget {
  const OrderTile({super.key, required this.order});

  /// Заявка клиента.
  final ClientOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(order.status, scheme);
    final label = _statusLabel(order.status);
    final filled = order.filledQtyBatch ?? order.filled ?? 0;
    final qty = order.qtyBatch ?? order.qty ?? order.qtyUnits;
    final priceLabel = order.type == OrderType.market
        ? 'По рынку'
        : (order.price != null ? order.price!.toStringAsFixed(2) : '—');
    return AppListTile(
      // Заявка на вкладке «Портфель», а торговля инструментом — в ветке
      // «Рынок». go_router переключает ветку и открывает инструмент;
      // push не годится — отрисовал бы страницу в неактивной ветке.
      onTap: () => context.go(
        '/market/${order.symbol}',
        extra: MarketSecurity(
          symbol: order.symbol,
          shortName: order.symbol,
          exchange: order.exchange,
        ),
      ),
      title: order.symbol,
      subtitleWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${_sideLabel(order.side)} · ${_typeLabel(order.type)} · ${_formatTime(order.updateTime ?? order.transTime)}',
            style: text.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Container(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _orderStat(
              context,
              'Объём:',
              qty != null ? '$qty' : '—',
              mono: qty != null,
            ),
            const SizedBox(height: 4),
            _orderStat(
              context,
              'Цена:',
              priceLabel,
              mono: order.type != OrderType.market,
            ),
            if (filled > 0) ...[
              const SizedBox(height: 4),
              _orderStat(context, 'Исполнено:', '$filled', mono: true),
            ],
            if (order.isActive) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _handleCancelOrder(context, ref, order),
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

String _sideLabel(OrderSide side) =>
    side == OrderSide.buy ? 'Покупка' : 'Продажа';

String _typeLabel(OrderType type) =>
    type == OrderType.limit ? 'Лимит' : 'Рыночная';

String _statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.working:
      return 'Активна';
    case OrderStatus.filled:
      return 'Исполнена';
    case OrderStatus.canceled:
      return 'Отменена';
    case OrderStatus.rejected:
      return 'Отклонена';
    case OrderStatus.unknown:
      return 'Неизвестно';
  }
}

Color _statusColor(OrderStatus status, ColorScheme scheme) {
  switch (status) {
    case OrderStatus.working:
      return scheme.primary;
    case OrderStatus.filled:
      return AppColors.success;
    case OrderStatus.canceled:
      return scheme.onSurfaceVariant;
    case OrderStatus.rejected:
      return scheme.error;
    case OrderStatus.unknown:
      return scheme.outline;
  }
}

String _formatTime(DateTime? value) {
  if (value == null) return '--:--';
  final local = value.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Строка заявки «label значение» — значение моноширинным, если это число.
Widget _orderStat(
  BuildContext context,
  String label,
  String value, {
  required bool mono,
}) {
  final text = Theme.of(context).textTheme;
  return Text.rich(
    TextSpan(
      style: text.bodySmall,
      children: [
        TextSpan(text: '$label '),
        TextSpan(
          text: value,
          style: mono ? monoNum(size: 12, weight: FontWeight.w500) : null,
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
    textAlign: TextAlign.right,
  );
}

Future<void> _handleCancelOrder(
  BuildContext context,
  WidgetRef ref,
  ClientOrder order,
) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Отменить заявку?'),
      content: Text(
        'Вы уверены, что хотите отменить заявку на ${_sideLabel(order.side).toLowerCase()} ${order.symbol}?',
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
    final cancelOrder = ref.read(cancelOrderProvider);
    await cancelOrder(
      orderId: order.id,
      portfolio: order.portfolio,
      exchange: order.exchange,
    );

    if (context.mounted) {
      showTopNotification(context, 'Заявка отменена');
    }
  } catch (e) {
    if (context.mounted) {
      showTopNotification(context, 'Ошибка отмены: $e', isError: true);
    }
  }
}
