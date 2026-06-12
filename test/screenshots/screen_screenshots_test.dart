import 'dart:async';

import 'package:aloria/core/theme/app_theme.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/application/order_book_notifier.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/order_failure.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/portfolio_trade.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/positions/widgets/order_tile.dart';
import 'package:aloria/features/market/presentation/positions/widgets/orders_list_section.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_hero.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_tabs_header.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_title_bar.dart';
import 'package:aloria/features/market/presentation/positions/widgets/position_tile.dart';
import 'package:aloria/features/market/presentation/positions/widgets/positions_list_section.dart';
import 'package:aloria/features/market/presentation/positions/widgets/trades_list_section.dart';
import 'package:aloria/features/market/presentation/trade/widgets/order_failure_sheet.dart';
import 'package:aloria/features/market/presentation/trade_page.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_kit.dart';

/// Скриншот-харнесс экранов портфеля и торговли на фикстурах.
/// Запуск: flutter test test/screenshots/screen_screenshots_test.dart
/// Результат: build/screen_shots/*.png

const _outDir = 'build/screen_shots';
const _phone = Size(430, 932); // iPhone Pro Max логические точки

final _ts = DateTime(2026, 6, 1, 14, 30);

// ── Фикстуры портфеля ────────────────────────────────────────────────────────

const _positions = <Position>[
  Position(
    symbol: 'SBER',
    exchange: 'TEREX',
    quantity: 30,
    averagePrice: 285.40,
    currency: 'RUB',
    volume: 8562,
    currentVolume: 8952.6,
    unrealisedPl: 390.6,
  ),
  Position(
    symbol: 'GAZP',
    exchange: 'TEREX',
    quantity: 50,
    averagePrice: 128.30,
    currency: 'RUB',
    volume: 6415,
    currentVolume: 6190,
    unrealisedPl: -225,
  ),
  Position(
    symbol: 'LKOH',
    exchange: 'TEREX',
    quantity: 1,
    averagePrice: 7250,
    currency: 'RUB',
    volume: 7250,
    currentVolume: 7321,
    unrealisedPl: 71,
  ),
  Position(
    symbol: 'YDEX',
    exchange: 'TEREX',
    quantity: 2,
    averagePrice: 4180,
    currency: 'RUB',
    volume: 8360,
    currentVolume: 8104,
    unrealisedPl: -256,
  ),
  Position(
    symbol: 'RUB',
    exchange: 'TEREX',
    quantity: 12450.55,
    averagePrice: 1,
    currency: 'RUB',
    volume: 12450.55,
    currentVolume: 12450.55,
  ),
];

const _summary = PortfolioSummary(
  buyingPower: 12450.55,
  currency: 'RUB',
  liquidationValue: 43018.15,
);

final _orders = <ClientOrder>[
  ClientOrder(
    id: '41005',
    symbol: 'SBER',
    brokerSymbol: 'TEREX:SBER',
    portfolio: 'T00013',
    exchange: 'TEREX',
    type: OrderType.limit,
    side: OrderSide.buy,
    status: OrderStatus.working,
    existing: true,
    transTime: _ts.subtract(const Duration(minutes: 12)),
    qty: 10,
    price: 296.50,
  ),
  ClientOrder(
    id: '41004',
    symbol: 'GAZP',
    brokerSymbol: 'TEREX:GAZP',
    portfolio: 'T00013',
    exchange: 'TEREX',
    type: OrderType.limit,
    side: OrderSide.sell,
    status: OrderStatus.working,
    existing: true,
    transTime: _ts.subtract(const Duration(minutes: 40)),
    qty: 20,
    filled: 8,
    filledQtyBatch: 8,
    price: 124.10,
  ),
  ClientOrder(
    id: '41003',
    symbol: 'LKOH',
    brokerSymbol: 'TEREX:LKOH',
    portfolio: 'T00013',
    exchange: 'TEREX',
    type: OrderType.market,
    side: OrderSide.buy,
    status: OrderStatus.filled,
    existing: true,
    transTime: _ts.subtract(const Duration(hours: 2)),
    qty: 1,
    filled: 1,
  ),
  ClientOrder(
    id: '41002',
    symbol: 'YDEX',
    brokerSymbol: 'TEREX:YDEX',
    portfolio: 'T00013',
    exchange: 'TEREX',
    type: OrderType.limit,
    side: OrderSide.buy,
    status: OrderStatus.rejected,
    existing: true,
    comment: 'Недостаточно средств для исполнения заявки',
    transTime: _ts.subtract(const Duration(hours: 3)),
    qty: 5,
    price: 4050,
  ),
];

final _trades = <PortfolioTrade>[
  PortfolioTrade(
    id: '7001',
    symbol: 'SBER',
    exchange: 'TEREX',
    side: OrderSide.buy,
    existing: true,
    orderId: '41003',
    date: _ts.subtract(const Duration(minutes: 25)),
    qty: 10,
    qtyUnits: 100,
    price: 298.10,
    volume: 29810,
  ),
  PortfolioTrade(
    id: '7000',
    symbol: 'GAZP',
    exchange: 'TEREX',
    side: OrderSide.sell,
    existing: true,
    orderId: '41001',
    date: _ts.subtract(const Duration(hours: 3)),
    qty: 8,
    qtyUnits: 80,
    price: 124.85,
    volume: 9988,
  ),
  PortfolioTrade(
    id: '6999',
    symbol: 'LKOH',
    exchange: 'TEREX',
    side: OrderSide.buy,
    existing: true,
    date: _ts.subtract(const Duration(days: 1, hours: 2)),
    qty: 1,
    qtyUnits: 1,
    price: 7250,
    volume: 7250,
  ),
];

final _stopOrders = <StopOrder>[
  StopOrder(
    id: '9001',
    symbol: 'SBER',
    portfolio: 'T00013',
    exchange: 'TEREX',
    side: OrderSide.sell,
    condition: StopCondition.lessOrEqual,
    status: OrderStatus.working,
    isStopLimit: true,
    existing: true,
    stopPrice: 285.00,
    price: 284.50,
    qty: 10,
    transTime: _ts.subtract(const Duration(hours: 1)),
  ),
];

// ── Фикстуры торговли ────────────────────────────────────────────────────────

final _quote = MarketPrice(
  instrumentId: 'SBER',
  price: 298.42,
  ts: _ts,
  description: 'Сбербанк России ПАО ао',
  currency: 'RUB',
  instrumentType: 'CS',
  prevClose: 296.06,
  open: 296.40,
  high: 299.10,
  low: 295.80,
  change: 2.36,
  changePercent: 0.80,
  volume: 5614360,
  bid: 298.40,
  ask: 298.44,
  lotSize: 10,
  minStep: 0.02,
);

final _history = List<MarketPrice>.generate(10, (i) {
  final prices = [297.9, 298.0, 298.1, 297.95, 298.2, 298.3, 298.25, 298.4, 298.38, 298.42];
  return MarketPrice(
    instrumentId: 'SBER',
    price: prices[i],
    ts: _ts.subtract(Duration(seconds: (10 - i) * 7)),
  );
});

final _candles = List<Candle>.generate(30, (i) {
  const base = <double>[
    294.2, 294.8, 294.5, 295.3, 295.0, 295.9, 296.4, 296.1, 296.8, 296.5,
    297.2, 296.9, 297.5, 297.1, 296.6, 297.0, 297.8, 298.2, 297.9, 298.5,
    298.1, 297.6, 298.0, 298.6, 298.9, 298.4, 298.8, 299.0, 298.6, 298.42,
  ];
  final open = i == 0 ? 294.0 : base[i - 1];
  final close = base[i];
  final hi = (open > close ? open : close) + 0.25;
  final lo = (open < close ? open : close) - 0.25;
  return Candle(
    ts: _ts.subtract(Duration(minutes: (30 - i) * 5)),
    open: open,
    high: hi,
    low: lo,
    close: close,
    volume: 1200 + (i * 37) % 900,
  );
});

final _book = OrderBook(
  bids: const [
    OrderBookLevel(price: 298.40, volume: 160),
    OrderBookLevel(price: 298.38, volume: 90),
    OrderBookLevel(price: 298.36, volume: 210),
    OrderBookLevel(price: 298.30, volume: 340),
    OrderBookLevel(price: 298.26, volume: 120),
    OrderBookLevel(price: 298.20, volume: 540),
    OrderBookLevel(price: 298.10, volume: 380),
    OrderBookLevel(price: 298.00, volume: 760),
    OrderBookLevel(price: 297.90, volume: 220),
    OrderBookLevel(price: 297.80, volume: 410),
  ],
  asks: const [
    OrderBookLevel(price: 298.44, volume: 140),
    OrderBookLevel(price: 298.46, volume: 70),
    OrderBookLevel(price: 298.50, volume: 260),
    OrderBookLevel(price: 298.56, volume: 190),
    OrderBookLevel(price: 298.60, volume: 480),
    OrderBookLevel(price: 298.70, volume: 320),
    OrderBookLevel(price: 298.80, volume: 650),
    OrderBookLevel(price: 298.90, volume: 180),
    OrderBookLevel(price: 299.00, volume: 900),
    OrderBookLevel(price: 299.10, volume: 270),
  ],
  ts: _ts,
  snapshot: true,
  existing: true,
);

final _news = <MarketNews>[
  MarketNews(
    id: 1,
    title: 'Сбербанк отчитался о прибыли за квартал выше прогнозов',
    content: 'Чистая прибыль выросла на 12% год к году.',
    publishedAt: _ts.subtract(const Duration(hours: 1)),
    symbols: const ['SBER'],
  ),
  MarketNews(
    id: 2,
    title: 'Совет директоров обсудит дивидендную политику в июле',
    content: 'Заседание запланировано на середину месяца.',
    publishedAt: _ts.subtract(const Duration(hours: 5)),
    symbols: const ['SBER'],
  ),
];

// ── Фейковые нотифаеры ──────────────────────────────────────────────────────

class _FakeFeed extends PriceFeedNotifier {
  @override
  Future<PriceFeedState> build(PriceFeedParams arg) async => PriceFeedState(
        latest: _quote,
        history: _history,
        candles: _candles,
        fromCache: false,
      );
}

class _FakeBook extends OrderBookNotifier {
  @override
  Future<OrderBook?> build(OrderBookParams arg) async => _book;
}

// ── Обвязка ─────────────────────────────────────────────────────────────────

List<Override> _marketOverrides() => [
      positionsProvider.overrideWith((ref) => Stream.value(_positions)),
      portfolioSummaryProvider.overrideWith((ref) => Stream.value(_summary)),
      ordersProvider.overrideWith((ref) => Stream.value(_orders)),
      priceFeedProvider.overrideWith(_FakeFeed.new),
      orderBookProvider.overrideWith(_FakeBook.new),
      marketNewsProvider.overrideWith((ref, symbol) => Future.value(_news)),
      instrumentDetailProvider.overrideWith(
        (ref, params) => Future.value(_quote),
      ),
    ];

Widget _app(Widget home, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Точная копия композиции _PositionsBlock из positions_page.dart —
/// собственно страница без auth/learning-обвязки (та не влияет на вид).
class _PortfolioScreen extends ConsumerWidget {
  const _PortfolioScreen({required this.tab, this.positionsError = false});

  final PortfolioTab tab;
  final bool positionsError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = positionsError
        ? AsyncValue<List<Position>>.error(
            Exception('boom'), StackTrace.empty)
        : const AsyncValue.data(_positions);
    final orders = AsyncValue.data(_orders);
    final trades = AsyncValue.data(_trades);
    final stopOrders = AsyncValue.data(_stopOrders);
    const summary = AsyncValue.data(_summary);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const PortfolioTitleBar(),
                  const SizedBox(height: 12),
                  PortfolioHero(
                    summary: summary,
                    positions: positions,
                    onTopUp: () {},
                  ),
                  const SizedBox(height: 18),
                  PortfolioTabsHeader(
                    selected: tab,
                    positionsCount: 5,
                    ordersCount: 3,
                    tradesCount: 3,
                    onSelected: (_) {},
                  ),
                  const SizedBox(height: 12),
                  if (tab == PortfolioTab.positions)
                    PositionsListSection(positions: positions)
                  else if (tab == PortfolioTab.orders)
                    OrdersListSection(orders: orders, stopOrders: stopOrders)
                  else
                    TradesListSection(trades: trades),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _shootScreen(
  WidgetTester tester,
  String name,
  Widget home, {
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester)? act,
  double height = 932,
}) async {
  await tester.binding.setSurfaceSize(Size(_phone.width, height));
  tester.view.devicePixelRatio = 1.0;
  const key = ValueKey('screen-boundary');
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: _app(home, overrides: overrides),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 1200));
  if (act != null) {
    await act(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 900));
  }
  await snapKey(tester, key, '$_outDir/$name.png');
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadShotFonts);

  testWidgets('портфель — позиции', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_positions',
      const _PortfolioScreen(tab: PortfolioTab.positions),
    );
  });

  testWidgets('портфель — заявки', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_orders',
      const _PortfolioScreen(tab: PortfolioTab.orders),
    );
  });

  testWidgets('портфель — детали позиции', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_position_details',
      const _PortfolioScreen(tab: PortfolioTab.positions),
      act: (t) => t.tap(find.byType(PositionTile).first),
    );
  });

  testWidgets('портфель — детали заявки', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_order_details',
      const _PortfolioScreen(tab: PortfolioTab.orders),
      act: (t) => t.tap(find.byType(OrderTile).first),
    );
  });

  testWidgets('ошибка заявки — продажа бумаг, которых нет', (tester) async {
    await _shootScreen(
      tester,
      'order_failure_short',
      const _PortfolioScreen(tab: PortfolioTab.positions),
      overrides: _marketOverrides(),
      act: (t) async {
        final ctx = t.element(find.byType(PortfolioTitleBar));
        unawaited(showOrderFailureSheet(
          ctx,
          failure: OrderFailure.fromRejectionComment(
            'Заявка приводит к отрицательной позиции по инструменту, '
            'который недоступен в маржу',
          ),
          symbol: 'OZON',
        ));
      },
    );
  });

  testWidgets('ошибка заявки — не хватает денег', (tester) async {
    await _shootScreen(
      tester,
      'order_failure_funds',
      const _PortfolioScreen(tab: PortfolioTab.positions),
      overrides: _marketOverrides(),
      act: (t) async {
        final ctx = t.element(find.byType(PortfolioTitleBar));
        unawaited(showOrderFailureSheet(
          ctx,
          failure: const OrderFailure(
            kind: OrderFailureKind.insufficientFunds,
            code: 'OrderCreatesUncoveredRisk',
            message: 'Недостаточно свободных средств. '
                'Услуга 100% обеспечение включена.',
          ),
          symbol: 'SBER',
        ));
      },
    );
  });

  testWidgets('ошибка заявки — цена вне лимита', (tester) async {
    await _shootScreen(
      tester,
      'order_failure_price',
      const _PortfolioScreen(tab: PortfolioTab.positions),
      overrides: _marketOverrides(),
      act: (t) async {
        final ctx = t.element(find.byType(PortfolioTitleBar));
        unawaited(showOrderFailureSheet(
          ctx,
          failure: const OrderFailure(
            kind: OrderFailureKind.badPrice,
            code: 'InternalErrorWithPrices',
            message: 'Цена заявки за пределами лимита',
          ),
          symbol: 'SBER',
        ));
      },
    );
  });

  testWidgets('портфель — пустой', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    const key = ValueKey('screen-boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          Scaffold(
            body: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  const PortfolioTitleBar(),
                  const SizedBox(height: 12),
                  PortfolioHero(
                    summary: const AsyncValue.data(PortfolioSummary(
                      buyingPower: 15000,
                      currency: 'RUB',
                      liquidationValue: 15000,
                    )),
                    positions: const AsyncValue.data(<Position>[]),
                    onTopUp: () {},
                  ),
                  const SizedBox(height: 18),
                  PortfolioTabsHeader(
                    selected: PortfolioTab.positions,
                    positionsCount: 0,
                    ordersCount: 0,
                    tradesCount: 0,
                    onSelected: (_) {},
                  ),
                  const SizedBox(height: 12),
                  const PositionsListSection(
                    positions: AsyncValue.data(<Position>[]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await snapKey(tester, key, '$_outDir/portfolio_empty.png');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('портфель — сделки', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_trades',
      const _PortfolioScreen(tab: PortfolioTab.trades),
    );
  });

  testWidgets('торговый экран — стоп-форма', (tester) async {
    await _shootScreen(
      tester,
      'trade_stop_form',
      const TradePage(symbol: 'SBER', shortName: 'Сбербанк'),
      overrides: _marketOverrides(),
      height: 1700,
      act: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Стоп'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Стоп'), warnIfMissed: false);
      },
    );
  });

  testWidgets('портфель — ошибка загрузки', (tester) async {
    await _shootScreen(
      tester,
      'portfolio_error',
      const _PortfolioScreen(tab: PortfolioTab.positions, positionsError: true),
    );
  });

  testWidgets('торговый экран — новости', (tester) async {
    await _shootScreen(
      tester,
      'trade_news',
      const TradePage(symbol: 'SBER', shortName: 'Сбербанк'),
      overrides: _marketOverrides(),
    );
  });

  testWidgets('торговый экран — стакан', (tester) async {
    await _shootScreen(
      tester,
      'trade_orderbook',
      const TradePage(symbol: 'SBER', shortName: 'Сбербанк'),
      overrides: _marketOverrides(),
      height: 2100,
      act: (tester) async {
        await tester.tap(find.text('Стакан'), warnIfMissed: false);
      },
    );
  });

  testWidgets('торговый экран — лимитная форма', (tester) async {
    await _shootScreen(
      tester,
      'trade_limit_form',
      const TradePage(symbol: 'SBER', shortName: 'Сбербанк'),
      overrides: _marketOverrides(),
      act: (tester) async {
        await tester.scrollUntilVisible(
          find.text('Лимитная'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Лимитная'), warnIfMissed: false);
      },
    );
  });
}
