import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/positions/widgets/details_sheet_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Открывает шторку со всеми деталями условной (стоп) заявки.
Future<void> showStopOrderDetails(BuildContext context, StopOrder order) {
  return showDetailsSheet(
    context,
    (ctx) => _StopOrderDetailsSheet(
      order: order,
      onTrade: () {
        Navigator.of(ctx).pop();
        context.go(
          '/market/${order.symbol}',
          extra: MarketSecurity(
            symbol: order.symbol,
            shortName: order.symbol,
            exchange: order.exchange,
          ),
        );
      },
    ),
  );
}

class _StopOrderDetailsSheet extends StatelessWidget {
  const _StopOrderDetailsSheet({required this.order, required this.onTrade});

  final StopOrder order;
  final VoidCallback onTrade;

  String get _conditionValue {
    final price = order.stopPrice?.toStringAsFixed(2) ?? '—';
    return switch (order.condition) {
      StopCondition.more => 'цена > $price',
      StopCondition.moreOrEqual => 'цена ≥ $price',
      StopCondition.less => 'цена < $price',
      StopCondition.lessOrEqual => 'цена ≤ $price',
    };
  }

  bool get _isDown =>
      order.condition == StopCondition.less ||
      order.condition == StopCondition.lessOrEqual;

  String get _statusLabel => switch (order.status) {
    OrderStatus.working => 'Ждёт цену',
    OrderStatus.filled => 'Сработала',
    OrderStatus.canceled => 'Отменена',
    OrderStatus.rejected => 'Отклонена',
    OrderStatus.unknown => 'Неизвестно',
  };

  String get _statusDescription => switch (order.status) {
    OrderStatus.working =>
      'Заявка пока не на бирже: она следит за ценой и ждёт условия срабатывания.',
    OrderStatus.filled =>
      'Условие выполнилось — на биржу ушла обычная заявка. Ищи её на вкладке «Заявки».',
    OrderStatus.canceled => 'Заявка снята и больше не следит за ценой.',
    OrderStatus.rejected => 'Система не приняла заявку.',
    OrderStatus.unknown => 'Статус не удалось распознать.',
  };

  Color _statusColor(ColorScheme scheme) => switch (order.status) {
    OrderStatus.working => AppColors.warning,
    OrderStatus.filled => AppColors.success,
    OrderStatus.canceled => scheme.onSurfaceVariant,
    OrderStatus.rejected => scheme.error,
    OrderStatus.unknown => scheme.outline,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBuy = order.side == OrderSide.buy;

    return DetailsSheetShell(
      symbol: order.symbol,
      title: order.symbol,
      subtitle: order.isStopLimit ? 'Стоп-лимитная заявка' : 'Стоп-заявка',
      actionLabel: 'Торговать инструментом',
      onAction: onTrade,
      rows: [
        DetailsInfoRow(
          label: 'Статус',
          value: _statusLabel,
          description: _statusDescription,
          valueColor: _statusColor(scheme),
        ),
        DetailsInfoRow(
          label: 'Условие',
          value: _conditionValue,
          description: _isDown
              ? 'Заявка сработает, когда цена опустится до этого уровня или ниже.'
              : 'Заявка сработает, когда цена поднимется до этого уровня или выше.',
          mono: true,
        ),
        DetailsInfoRow(
          label: 'Направление',
          value: isBuy ? 'Покупка' : 'Продажа',
          description: isBuy
              ? 'После срабатывания на биржу уйдёт заявка на покупку.'
              : 'После срабатывания на биржу уйдёт заявка на продажу.',
          valueColor: isBuy ? AppColors.success : AppColors.error,
        ),
        DetailsInfoRow(
          label: 'Что уйдёт на биржу',
          value: order.isStopLimit ? 'Лимитная заявка' : 'Рыночная заявка',
          description: order.isStopLimit
              ? 'После срабатывания выставится лимитная заявка по указанной цене — исполнение по ней не гарантировано, но цена под контролем.'
              : 'После срабатывания выставится рыночная заявка — исполнится сразу, но цена может отличаться от цены срабатывания.',
        ),
        if (order.isStopLimit && order.price != null)
          DetailsInfoRow(
            label: 'Лимитная цена',
            value: order.price!.toStringAsFixed(2),
            description:
                'Граница для заявки, которая уйдёт на биржу после срабатывания.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Количество',
          value: order.qty != null ? '${order.qty}' : '—',
          description: 'Сколько лотов будет в заявке после срабатывания.',
          mono: order.qty != null,
        ),
        DetailsInfoRow(
          label: 'Выставлена',
          value: detailsDateTime(order.transTime),
          description: 'Момент, когда ты создал условную заявку.',
          mono: true,
        ),
        if (order.endTime != null)
          DetailsInfoRow(
            label: 'Действует до',
            value: detailsDateTime(order.endTime),
            description:
                'Если условие не выполнится к этому моменту, заявка отменится сама.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Номер заявки',
          value: order.id,
          description: 'Уникальный номер условной заявки.',
          mono: true,
        ),
      ],
    );
  }
}
