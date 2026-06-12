import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/positions/widgets/details_sheet_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Открывает шторку со всей детальной информацией по позиции. Кнопка
/// «Торговать инструментом» внутри шторки переключает на ветку «Рынок».
Future<void> showPositionDetails(BuildContext context, Position position) {
  return showDetailsSheet(
    context,
    (ctx) => _PositionDetailsSheet(
      position: position,
      onTrade: () {
        Navigator.of(ctx).pop();
        context.go(
          '/market/${position.symbol}',
          extra: MarketSecurity(
            symbol: position.symbol,
            shortName: position.symbol,
            exchange: position.exchange,
          ),
        );
      },
    ),
  );
}

class _PositionDetailsSheet extends StatelessWidget {
  const _PositionDetailsSheet({required this.position, required this.onTrade});

  final Position position;
  final VoidCallback onTrade;

  /// Есть ли смысл показывать разбивку по расчётным дням.
  static bool _hasSettlementSplit(Position p) =>
      p.qtyT0 != null &&
      p.qtyT1 != null &&
      (p.qtyT0 != p.qtyUnits || p.qtyT1 != p.qtyT0);

  @override
  Widget build(BuildContext context) {
    // RUB — это денежная позиция (кэш), а не торгуемый инструмент,
    // поэтому кнопку перехода в торговлю для неё не показываем.
    final isCash = position.symbol.toUpperCase() == 'RUB';

    return DetailsSheetShell(
      symbol: position.symbol,
      title: position.symbol,
      subtitle: position.shortName?.isNotEmpty == true
          ? position.shortName
          : null,
      actionLabel: isCash ? null : 'Торговать инструментом',
      onAction: isCash ? null : onTrade,
      rows: [
        DetailsInfoRow(
          label: 'Количество',
          value: position.qtyUnits != null
              ? '${detailsNum(position.qtyUnits!)} шт.'
              : '${detailsNum(position.quantity)} шт.',
          description: position.lotSize != null && position.lotSize! > 1
              ? 'Бумаг на счёте. Торгуются лотами по ${detailsNum(position.lotSize!)} шт.'
              : 'Количество бумаг на счёте.',
          mono: true,
        ),
        if (_hasSettlementSplit(position))
          DetailsInfoRow(
            label: 'Доступно сейчас (T0)',
            value: '${detailsNum(position.qtyT0!)} шт.',
            description:
                'Расчёты по этим бумагам завершены — их можно продать прямо сейчас.',
            mono: true,
          ),
        if (_hasSettlementSplit(position) &&
            (position.qtyT1 ?? 0) != (position.qtyT0 ?? 0))
          DetailsInfoRow(
            label: 'Будет доступно завтра (T1)',
            value: '${detailsNum(position.qtyT1!)} шт.',
            description:
                'Куплено сегодня: рынок работает в режиме T+1, расчёт завершится на следующий торговый день.',
            mono: true,
          ),
        if (position.openUnits != null &&
            position.openUnits != position.qtyUnits)
          DetailsInfoRow(
            label: 'Было на начало дня',
            value: '${detailsNum(position.openUnits!)} шт.',
            description:
                'Сколько бумаг было утром — разница с текущим количеством показывает сегодняшние сделки.',
            mono: true,
          ),
        DetailsInfoRow(
          label: 'Средняя цена',
          value:
              '${position.averagePrice.toStringAsFixed(2)} ${position.currency}',
          description:
              'Цена покупки (усреднённая, если было несколько сделок). От неё считается твой результат.',
          mono: true,
        ),
        DetailsInfoRow(
          label: 'Вложено',
          value: '${position.volume.toStringAsFixed(2)} ${position.currency}',
          description:
              'Сколько денег потрачено на этот пакет по средней цене покупки.',
          mono: true,
        ),
        DetailsInfoRow(
          label: 'Текущая стоимость',
          value:
              '${position.currentVolume.toStringAsFixed(2)} ${position.currency}',
          description:
              'Рыночная стоимость всего пакета бумаг сейчас — столько получится при продаже по текущей цене.',
          mono: true,
        ),
        if (position.unrealisedPl != null)
          DetailsInfoRow(
            label: 'Результат (П/У)',
            value:
                '${position.unrealisedPl! >= 0 ? '+' : ''}${position.unrealisedPl!.toStringAsFixed(2)} ${position.currency}',
            description:
                '«Бумажная» прибыль или убыток: разница между текущей стоимостью и вложенным. Станет настоящей только после продажи.',
            mono: true,
          ),
        if (position.dailyUnrealisedPl != null)
          DetailsInfoRow(
            label: 'Результат за сегодня',
            value:
                '${position.dailyUnrealisedPl! >= 0 ? '+' : ''}${position.dailyUnrealisedPl!.toStringAsFixed(2)} ${position.currency}',
            description:
                'Как изменилась оценка позиции с начала сегодняшних торгов.',
            mono: true,
          ),
      ],
    );
  }
}
