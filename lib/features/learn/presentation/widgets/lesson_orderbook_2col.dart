import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/presentation/widgets/order_book_widget.dart';
import 'package:flutter/material.dart';

/// Двухколоночный стакан как в торговле — переиспускает боевой
/// [OrderBookWidget] на замоканных данных. Для уроков про стакан/спред:
/// тот же вид, что увидит пользователь на реальном инструменте.
class LessonOrderbookTwoCol extends StatelessWidget {
  const LessonOrderbookTwoCol({super.key, required this.tint});

  final Color tint;

  static final _book = OrderBook(
    bids: const [
      OrderBookLevel(price: 100.00, volume: 160),
      OrderBookLevel(price: 99.99, volume: 130),
      OrderBookLevel(price: 99.98, volume: 90),
      OrderBookLevel(price: 99.97, volume: 210),
      OrderBookLevel(price: 99.96, volume: 70),
    ],
    asks: const [
      OrderBookLevel(price: 100.01, volume: 140),
      OrderBookLevel(price: 100.02, volume: 110),
      OrderBookLevel(price: 100.03, volume: 180),
      OrderBookLevel(price: 100.04, volume: 60),
      OrderBookLevel(price: 100.05, volume: 120),
    ],
    ts: DateTime(2024, 1, 1, 10, 30, 12),
    snapshot: true,
    existing: true,
  );

  @override
  Widget build(BuildContext context) {
    return OrderBookWidget(book: _book, maxLevels: 5);
  }
}
