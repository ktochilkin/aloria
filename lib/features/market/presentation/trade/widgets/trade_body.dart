import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/trade/trade_providers.dart';
import 'package:aloria/features/market/presentation/trade/widgets/candle_chart.dart';
import 'package:aloria/features/market/presentation/trade/widgets/feed_tabs_section.dart';
import 'package:aloria/features/market/presentation/trade/widgets/instrument_header_card.dart';
import 'package:aloria/features/market/presentation/trade/widgets/order_form_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Тело торговой страницы: шапка инструмента, свечной график,
/// «Пульс рынка» и форма новой заявки.
class TradeBody extends StatelessWidget {
  const TradeBody({
    super.key,
    required this.symbol,
    required this.exchange,
    required this.state,
    required this.orderBook,
    required this.news,
    required this.feedTab,
    required this.onFeedTabChanged,
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
    required this.onSelectPrice,
    required this.scrollController,
  });

  /// Тикер инструмента.
  final String symbol;

  /// Биржа.
  final String exchange;

  /// Состояние потока котировок (последняя цена, история, свечи).
  final PriceFeedState state;

  /// Стакан.
  final AsyncValue<OrderBook?> orderBook;

  /// Новости по инструменту.
  final AsyncValue<List<MarketNews>> news;

  /// Активная вкладка «Пульса рынка».
  final FeedTab feedTab;

  /// Колбэк выбора вкладки «Пульса рынка».
  final ValueChanged<FeedTab> onFeedTabChanged;

  /// Выбранный вид заявки.
  final OrderFormKind kind;

  /// Смена вида заявки.
  final ValueChanged<OrderFormKind> onKindChanged;

  /// Контроллер поля количества.
  final TextEditingController qtyController;

  /// Контроллер поля цены (лимитная).
  final TextEditingController priceController;

  /// Контроллер цены срабатывания (стоп).
  final TextEditingController triggerController;

  /// Контроллер лимитной цены стоп-заявки.
  final TextEditingController stopLimitController;

  /// Условие срабатывания стоп-заявки.
  final StopCondition stopCondition;

  /// Смена условия срабатывания.
  final ValueChanged<StopCondition> onStopConditionChanged;

  /// Отправка заявки.
  final ValueChanged<OrderSide> onSubmit;

  /// Идёт отправка заявки.
  final bool submitting;

  /// Выбор цены из стакана.
  final ValueChanged<double> onSelectPrice;

  /// Контроллер прокрутки страницы (восстановление позиции).
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    final history = state.history;
    final candles = state.candles;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Builder(
        builder: (context) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(16, 16, 16, context.bottomNavBarPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InstrumentHeaderCard(
                symbol: symbol,
                exchange: exchange,
                price: latest,
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: candles.isEmpty
                      ? const SizedBox(
                          height: 200,
                          child: Center(child: Text('Нет данных для графика')),
                        )
                      : CandleChart(data: candles, scheme: scheme),
                ),
              ),
              const SizedBox(height: 12),
              FeedTabsSection(
                feedTab: feedTab,
                onFeedTabChanged: onFeedTabChanged,
                news: news,
                history: history,
                orderBook: orderBook,
                onSelectPrice: onSelectPrice,
              ),
              const SizedBox(height: 16),
              OrderFormSection(
                kind: kind,
                onKindChanged: onKindChanged,
                qtyController: qtyController,
                priceController: priceController,
                triggerController: triggerController,
                stopLimitController: stopLimitController,
                stopCondition: stopCondition,
                onStopConditionChanged: onStopConditionChanged,
                currentPrice: latest?.price,
                onSubmit: onSubmit,
                submitting: submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
