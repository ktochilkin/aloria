import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/presentation/widgets/order_book_widget.dart';
import 'package:flutter/material.dart';

/// Учебный блок к уроку про ликвидность: два мини-стакана — ликвидный
/// («телефон») и неликвидный («гараж»). Кнопка «продать по рынку» анимирует,
/// как рыночная заявка съедает заявки в стакане, и показывает, во сколько
/// обходится срочный выход: в ликвидном — почти по лучшей цене, в неликвидном —
/// с заметной потерей. Данные замоканы; строки переиспользуют [OrderBookRow]
/// из торгового стакана, чтобы вид совпадал с настоящим рынком.
class LessonLiquidityOrderbook extends StatefulWidget {
  const LessonLiquidityOrderbook({super.key, required this.tint});

  final Color tint;

  @override
  State<LessonLiquidityOrderbook> createState() =>
      _LessonLiquidityOrderbookState();
}

class _LessonLiquidityOrderbookState extends State<LessonLiquidityOrderbook>
    with SingleTickerProviderStateMixin {
  /// Сколько лотов продаём «по рынку» по нажатию кнопки.
  static const double _sellLots = 10;

  late final AnimationController _controller;
  bool _sold = false;

  // Замоканные стаканы. Ликвидный: плотные заявки, узкий спред.
  // Неликвидный: редкие заявки с дырами, широкий спред.
  static const _liquid = _MockBook(
    asks: [
      OrderBookLevel(price: 100.03, volume: 140),
      OrderBookLevel(price: 100.02, volume: 110),
      OrderBookLevel(price: 100.01, volume: 180),
    ],
    bids: [
      OrderBookLevel(price: 100.00, volume: 160),
      OrderBookLevel(price: 99.99, volume: 130),
      OrderBookLevel(price: 99.98, volume: 150),
    ],
  );

  static const _illiquid = _MockBook(
    asks: [
      OrderBookLevel(price: 103.00, volume: 6),
      OrderBookLevel(price: 101.80, volume: 9),
      OrderBookLevel(price: 101.00, volume: 5),
    ],
    bids: [
      OrderBookLevel(price: 100.00, volume: 3),
      OrderBookLevel(price: 99.00, volume: 4),
      OrderBookLevel(price: 97.50, volume: 10),
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sell() {
    setState(() => _sold = true);
    _controller.forward(from: 0);
  }

  void _reset() {
    setState(() => _sold = false);
    _controller.reset();
  }

  double get _consumed => _sold ? _controller.value * _sellLots : 0;

  bool get _done => _sold && _controller.value > 0.97;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScenarioCard(
          title: 'Ликвидная — как телефон',
          icon: Icons.smartphone,
          book: _liquid,
          consumed: _consumed,
          sellLots: _sellLots,
          showResult: _done,
          tint: widget.tint,
        ),
        const SizedBox(height: 12),
        _ScenarioCard(
          title: 'Неликвидная — как гараж',
          icon: Icons.warehouse_outlined,
          book: _illiquid,
          consumed: _consumed,
          sellLots: _sellLots,
          showResult: _done,
          tint: widget.tint,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _sold ? null : _sell,
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Продать 10 лотов по рынку'),
              ),
            ),
            if (_sold) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.replay),
                tooltip: 'Заново',
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Карточка одного сценария: подпись, мини-стакан и строка результата продажи.
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.title,
    required this.icon,
    required this.book,
    required this.consumed,
    required this.sellLots,
    required this.showResult,
    required this.tint,
  });

  final String title;
  final IconData icon;
  final _MockBook book;
  final double consumed;
  final double sellLots;
  final bool showResult;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bestAsk = book.asks
        .map((e) => e.price)
        .reduce((a, b) => a < b ? a : b);
    final bestBid = book.bids
        .map((e) => e.price)
        .reduce((a, b) => a > b ? a : b);
    final spread = bestAsk - bestBid;
    final spreadPct = spread / bestBid * 100;
    final fill = _marketSell(book.bids, sellLots, bestBid);

    final maxVol = [
      ...book.asks.map((e) => e.volume),
      ...book.bids.map((e) => e.volume),
    ].fold<double>(1, (p, v) => v > p ? v : p);

    final asks = [...book.asks]..sort((a, b) => b.price.compareTo(a.price));
    final bids = [...book.bids]..sort((a, b) => b.price.compareTo(a.price));

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 8),
              Text(
                title,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final level in asks)
            _OpacityRow(
              opacity: 1,
              child: OrderBookRow(
                level: level,
                isAsk: true,
                maxVolume: maxVol,
                color: AppColors.error,
              ),
            ),
          _SpreadBand(spread: spread, pct: spreadPct, tint: tint),
          for (var i = 0; i < bids.length; i++)
            _OpacityRow(
              // Заявки, которые «съела» рыночная продажа, гаснут.
              opacity: consumed > _startVolume(bids, i) ? 0.3 : 1,
              child: OrderBookRow(
                level: bids[i],
                isAsk: false,
                maxVolume: maxVol,
                color: AppColors.success,
              ),
            ),
          AnimatedOpacity(
            opacity: showResult ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ResultLine(
                lots: sellLots,
                avg: fill.avg,
                slippagePct: fill.slippagePct,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Суммарный объём заявок до уровня [index] (сколько надо «съесть», чтобы
  /// дойти до него).
  double _startVolume(List<OrderBookLevel> bids, int index) {
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += bids[i].volume;
    }
    return sum;
  }
}

/// Полоса спреда между лучшей продажей и лучшей покупкой.
class _SpreadBand extends StatelessWidget {
  const _SpreadBand({
    required this.spread,
    required this.pct,
    required this.tint,
  });

  final double spread;
  final double pct;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_vert, size: 15, color: tint),
          const SizedBox(width: 6),
          Text(
            'спред ${spread.toStringAsFixed(2)} ₽ · ${pct.toStringAsFixed(2)}%',
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Строка-итог: по какой средней цене реально удалось продать и сколько
/// потеряли против лучшей цены в стакане.
class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.lots,
    required this.avg,
    required this.slippagePct,
  });

  final double lots;
  final double avg;
  final double slippagePct;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bad = slippagePct >= 0.05;
    final color = bad ? AppColors.error : AppColors.success;
    final tail = bad
        ? '−${slippagePct.toStringAsFixed(2)}% к лучшей цене'
        : 'без потери в цене';
    return Row(
      children: [
        Icon(
          bad ? Icons.trending_down : Icons.check_circle_outline,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Продал ${lots.toInt()} лотов в среднем по '),
                TextSpan(
                  text: avg.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(text: ' — '),
                TextSpan(
                  text: tail,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _OpacityRow extends StatelessWidget {
  const _OpacityRow({required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 120),
      child: child,
    );
  }
}

/// Замоканный стакан для урока.
class _MockBook {
  const _MockBook({required this.asks, required this.bids});

  final List<OrderBookLevel> asks;
  final List<OrderBookLevel> bids;
}

/// Считает результат продажи [lots] лотов «по рынку»: проходит по заявкам на
/// покупку от лучшей к худшей и возвращает среднюю цену и проскальзывание
/// против лучшей цены.
({double avg, double slippagePct}) _marketSell(
  List<OrderBookLevel> bids,
  double lots,
  double bestBid,
) {
  final sorted = [...bids]..sort((a, b) => b.price.compareTo(a.price));
  var remaining = lots;
  var cost = 0.0;
  for (final level in sorted) {
    if (remaining <= 0) break;
    final take = remaining < level.volume ? remaining : level.volume;
    cost += take * level.price;
    remaining -= take;
  }
  final filled = lots - remaining;
  final avg = filled > 0 ? cost / filled : bestBid;
  final slippagePct = bestBid > 0 ? (bestBid - avg) / bestBid * 100 : 0.0;
  return (avg: avg, slippagePct: slippagePct);
}
