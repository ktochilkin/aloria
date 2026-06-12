import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/portfolio_trade.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/positions/widgets/details_sheet_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Открывает шторку со всеми деталями сделки и пояснениями к каждому полю.
Future<void> showTradeDetails(BuildContext context, PortfolioTrade trade) {
  return showDetailsSheet(
    context,
    (ctx) => _TradeDetailsSheet(
      trade: trade,
      onTrade: () {
        Navigator.of(ctx).pop();
        context.go(
          '/market/${trade.symbol}',
          extra: MarketSecurity(
            symbol: trade.symbol,
            shortName: trade.symbol,
            exchange: trade.exchange,
          ),
        );
      },
    ),
  );
}

class _TradeDetailsSheet extends StatelessWidget {
  const _TradeDetailsSheet({required this.trade, required this.onTrade});

  final PortfolioTrade trade;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.side == OrderSide.buy;
    final qty = trade.qty;
    final volume =
        trade.volume ??
        ((trade.price ?? 0) * (trade.qtyUnits ?? trade.qty ?? 0));

    return DetailsSheetShell(
      symbol: trade.symbol,
      title: trade.symbol,
      subtitle: 'Сделка',
      actionLabel: 'Торговать инструментом',
      onAction: onTrade,
      rows: [
        DetailsInfoRow(
          label: 'Направление',
          value: isBuy ? 'Покупка' : 'Продажа',
          description: isBuy
              ? 'Ты купил бумаги: деньги списаны, бумаги добавлены в портфель.'
              : 'Ты продал бумаги: бумаги списаны, деньги добавлены на счёт.',
          valueColor: isBuy ? AppColors.success : AppColors.error,
        ),
        DetailsInfoRow(
          label: 'Время',
          value: detailsDateTime(trade.date),
          description:
              'Момент, когда твоя заявка встретилась с заявкой другого участника — и сделка состоялась.',
          mono: true,
        ),
        if (trade.price != null)
          DetailsInfoRow(
            label: 'Цена',
            value: trade.price!.toStringAsFixed(2),
            description:
                'Фактическая цена за одну бумагу, по которой прошла сделка.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Количество',
          value: qty != null
              ? (trade.qtyUnits != null && trade.qtyUnits != qty
                    ? '$qty лот. (${trade.qtyUnits} шт.)'
                    : '$qty')
              : '${trade.qtyUnits ?? '—'}',
          description:
              'Объём этой сделки. Одна заявка может исполниться несколькими сделками, если встречных предложений было несколько.',
          mono: true,
        ),
        if (volume > 0)
          DetailsInfoRow(
            label: 'Сумма',
            value: '${volume.toStringAsFixed(2)} ₽',
            description: 'Сделка в деньгах: цена × количество бумаг.',
            mono: true,
          ),
        if (trade.commission != null)
          DetailsInfoRow(
            label: 'Комиссия',
            value: '${trade.commission!.toStringAsFixed(2)} ₽',
            description:
                'Плата брокеру за исполнение сделки. На реальном рынке она есть всегда — учитывай её в результате.',
            mono: true,
          ),
        if (trade.orderId != null)
          DetailsInfoRow(
            label: 'Заявка',
            value: '№ ${trade.orderId}',
            description:
                'Номер заявки, из которой родилась эта сделка. Найти её можно на вкладке «Заявки».',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Номер сделки',
          value: trade.id,
          description: 'Уникальный номер сделки на бирже.',
          mono: true,
        ),
      ],
    );
  }
}
