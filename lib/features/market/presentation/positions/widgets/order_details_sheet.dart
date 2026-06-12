import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/positions/widgets/details_sheet_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Открывает шторку со всеми деталями заявки и пояснениями к каждому полю.
Future<void> showOrderDetails(BuildContext context, ClientOrder order) {
  return showDetailsSheet(
    context,
    (ctx) => _OrderDetailsSheet(
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

class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({required this.order, required this.onTrade});

  final ClientOrder order;
  final VoidCallback onTrade;

  String get _statusLabel => switch (order.status) {
    OrderStatus.working => 'Активна',
    OrderStatus.filled => 'Исполнена',
    OrderStatus.canceled => 'Отменена',
    OrderStatus.rejected => 'Отклонена',
    OrderStatus.unknown => 'Неизвестно',
  };

  String get _statusDescription => switch (order.status) {
    OrderStatus.working =>
      'Заявка стоит в стакане и ждёт встречную: исполнится, как только найдётся подходящая цена.',
    OrderStatus.filled =>
      'Заявка полностью исполнена — сделка состоялась, бумаги и деньги уже в портфеле.',
    OrderStatus.canceled =>
      'Заявка снята и больше не участвует в торгах. Отменить её мог ты сам или биржа в конце дня.',
    OrderStatus.rejected =>
      'Система не приняла заявку — причина обычно указана в комментарии ниже.',
    OrderStatus.unknown => 'Статус не удалось распознать.',
  };

  Color _statusColor(ColorScheme scheme) => switch (order.status) {
    OrderStatus.working => scheme.primary,
    OrderStatus.filled => AppColors.success,
    OrderStatus.canceled => scheme.onSurfaceVariant,
    OrderStatus.rejected => scheme.error,
    OrderStatus.unknown => scheme.outline,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBuy = order.side == OrderSide.buy;
    final isLimit = order.type == OrderType.limit;
    final qty = order.qtyBatch ?? order.qty;
    final filled = order.filledQtyBatch ?? order.filled ?? 0;
    final isPartial =
        order.status == OrderStatus.working && filled > 0 && qty != null;

    return DetailsSheetShell(
      symbol: order.symbol,
      title: order.symbol,
      subtitle: isLimit ? 'Лимитная заявка' : 'Рыночная заявка',
      actionLabel: 'Торговать инструментом',
      onAction: onTrade,
      rows: [
        DetailsInfoRow(
          label: 'Статус',
          value: _statusLabel,
          description: _statusDescription,
          valueColor: _statusColor(scheme),
        ),
        if (order.comment?.isNotEmpty == true)
          DetailsInfoRow(
            label: 'Комментарий',
            value: order.comment!,
            description: order.status == OrderStatus.rejected
                ? 'Причина, по которой система отклонила заявку.'
                : 'Служебная пометка к заявке.',
          ),
        DetailsInfoRow(
          label: 'Направление',
          value: isBuy ? 'Покупка' : 'Продажа',
          description: isBuy
              ? 'Заявка на покупку: ты отдаёшь деньги и получаешь бумаги.'
              : 'Заявка на продажу: ты отдаёшь бумаги и получаешь деньги.',
          valueColor: isBuy ? AppColors.success : AppColors.error,
        ),
        DetailsInfoRow(
          label: 'Тип',
          value: isLimit ? 'Лимитная' : 'Рыночная',
          description: isLimit
              ? 'Исполнится только по указанной цене или лучше. Может ждать в стакане сколько угодно — в пределах срока действия.'
              : 'Исполняется сразу по лучшим ценам, которые есть в стакане. Цена заранее не гарантирована.',
        ),
        if (isLimit && order.price != null)
          DetailsInfoRow(
            label: 'Цена',
            value: order.price!.toStringAsFixed(2),
            description:
                'Граница, которую ты задал: купить не дороже / продать не дешевле этой цены.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Количество',
          value: qty != null
              ? (order.qtyUnits != null && order.qtyUnits != qty
                    ? '$qty лот. (${order.qtyUnits} шт.)'
                    : '$qty')
              : '—',
          description: 'Сколько лотов в заявке всего.',
          mono: qty != null,
        ),
        DetailsInfoRow(
          label: 'Исполнено',
          value: qty != null ? '${detailsNum(filled)} из $qty' : '—',
          description: isPartial
              ? 'Заявка исполнена частично: встречных предложений хватило не на весь объём. Остаток продолжает ждать в стакане.'
              : 'Какая часть заявки уже превратилась в сделки.',
          mono: true,
        ),
        if (order.volume != null)
          DetailsInfoRow(
            label: 'Объём',
            value: '${order.volume!.toStringAsFixed(2)} ₽',
            description: 'Сумма заявки в деньгах: цена × количество.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Выставлена',
          value: detailsDateTime(order.transTime),
          description: 'Момент, когда заявка попала на биржу.',
          mono: true,
        ),
        if (order.updateTime != null && order.updateTime != order.transTime)
          DetailsInfoRow(
            label: 'Обновлена',
            value: detailsDateTime(order.updateTime),
            description:
                'Последнее изменение: исполнение (полное или частичное), отмена или отклонение.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Срок действия',
          value: _timeInForceLabel(order.timeInForce),
          description: _timeInForceDescription(order.timeInForce),
        ),
        DetailsInfoRow(
          label: 'Номер заявки',
          value: order.id,
          description:
              'Уникальный номер на бирже. По нему сделки связываются с заявкой, которая их породила.',
          mono: true,
        ),
      ],
    );
  }

  static String _timeInForceLabel(String? value) =>
      switch (value?.toLowerCase()) {
        'oneday' => 'До конца дня',
        'goodtillcancelled' => 'До отмены',
        'fillorkill' => 'Всё или ничего',
        'immediateorcancel' => 'Сразу или отмена',
        null => 'До конца дня',
        _ => value!,
      };

  static String _timeInForceDescription(String? value) => switch (value
      ?.toLowerCase()) {
    'goodtillcancelled' =>
      'Заявка будет ждать исполнения, пока ты сам её не отменишь.',
    'fillorkill' => 'Исполнится только целиком и сразу — иначе будет отменена.',
    'immediateorcancel' =>
      'Исполнится сразу настолько, насколько возможно, остаток отменится.',
    _ =>
      'Если заявка не исполнится до конца торгового дня, биржа отменит её автоматически.',
  };
}
