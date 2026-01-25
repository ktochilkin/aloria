import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/market/application/order_book_notifier.dart';
import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _FeedTab { tape, orderBook }

final feedTabProvider = StateProvider.family<_FeedTab, String>((ref, symbol) {
  // Сохраняем состояние вкладки, чтобы не сбрасывалось
  ref.keepAlive();
  return _FeedTab.tape;
});

// Провайдер для сохранения позиции прокрутки
final scrollPositionProvider = StateProvider.family<double, String>(
  (ref, symbol) => 0.0,
);

class TradePage extends ConsumerStatefulWidget {
  const TradePage({
    super.key,
    required this.symbol,
    required this.shortName,
    this.exchange = 'TEREX',
  });

  final String symbol;
  final String shortName;
  final String exchange;

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> {
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  late final ScrollController _scrollController;
  bool _isLimit = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    // Создаем ScrollController с начальной позицией сразу
    final savedPosition = ref.read(scrollPositionProvider(widget.symbol));
    _scrollController = ScrollController(initialScrollOffset: savedPosition);

    // Сохраняем позицию при прокрутке
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        ref.read(scrollPositionProvider(widget.symbol).notifier).state =
            _scrollController.offset;
      }
    });
  }

  @override
  void dispose() {
    // Сохраняем позицию при выходе со страницы
    if (_scrollController.hasClients) {
      ref.read(scrollPositionProvider(widget.symbol).notifier).state =
          _scrollController.offset;
    }

    _qtyController.dispose();
    _priceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectPriceFromOrderBook(double price) {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLimit = true;
      _priceController.text = price.toStringAsFixed(2);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _submit(OrderSide side) async {
    final repo = await ref.read(marketDataRepositoryProvider.future);
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final limitPrice = double.tryParse(_priceController.text);
    final order = TradeOrder(
      symbol: widget.symbol,
      exchange: widget.exchange,
      side: side,
      type: _isLimit ? OrderType.limit : OrderType.market,
      quantity: qty,
      limitPrice: _isLimit ? limitPrice : null,
    );
    setState(() => _submitting = true);
    try {
      await repo.placeOrder(order);
      if (mounted) {
        showTopNotification(context, 'Заявка отправлена');
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Ошибка отправки: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(
      priceFeedProvider((symbol: widget.symbol, exchange: widget.exchange)),
    );
    final orderBook = ref.watch(
      orderBookProvider((
        symbol: widget.symbol,
        exchange: widget.exchange,
        instrumentGroup: null,
        depth: 10,
      )),
    );
    final feedTab = ref.watch(feedTabProvider(widget.symbol));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.symbol} · ${widget.shortName}')),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: feed.when(
          data: (state) => _TradeBody(
            symbol: widget.symbol,
            state: state,
            orderBook: orderBook,
            feedTab: feedTab,
            onFeedTabChanged: (tab) =>
                ref.read(feedTabProvider(widget.symbol).notifier).state = tab,
            isLimit: _isLimit,
            onToggleType: (value) => setState(() => _isLimit = value),
            qtyController: _qtyController,
            priceController: _priceController,
            onSubmit: _submit,
            submitting: _submitting,
            onSelectPrice: _selectPriceFromOrderBook,
            scrollController: _scrollController,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
        ),
      ),
    );
  }
}

class _TradeBody extends StatelessWidget {
  const _TradeBody({
    required this.symbol,
    required this.state,
    required this.orderBook,
    required this.feedTab,
    required this.onFeedTabChanged,
    required this.isLimit,
    required this.onToggleType,
    required this.qtyController,
    required this.priceController,
    required this.onSubmit,
    required this.submitting,
    required this.onSelectPrice,
    required this.scrollController,
  });

  final String symbol;
  final PriceFeedState state;
  final AsyncValue<OrderBook?> orderBook;
  final _FeedTab feedTab;
  final ValueChanged<_FeedTab> onFeedTabChanged;
  final bool isLimit;
  final ValueChanged<bool> onToggleType;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  final ValueChanged<OrderSide> onSubmit;
  final bool submitting;
  final ValueChanged<double> onSelectPrice;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    final history = state.history;
    final candles = state.candles;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest != null ? latest.price.toStringAsFixed(2) : '--',
                        style: text.headlineMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latest != null
                            ? 'обновлено ${latest.ts.toLocal()}'
                            : 'нет данных',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.auto_graph, size: 32, color: scheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: candles.isEmpty
                    ? const Center(child: Text('Нет данных для графика'))
                    : _CandleChart(data: candles, scheme: scheme),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Пульс рынка', style: text.titleMedium),
              Text(
                feedTab == _FeedTab.tape
                    ? 'Лента последних сделок'
                    : 'Биржевой стакан в реальном времени',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              SegmentedButton<_FeedTab>(
                segments: const [
                  ButtonSegment(
                    value: _FeedTab.tape,
                    icon: Icon(Icons.bolt),
                    label: Text('Лента'),
                  ),
                  ButtonSegment(
                    value: _FeedTab.orderBook,
                    icon: Icon(Icons.stacked_bar_chart),
                    label: Text('Стакан'),
                  ),
                ],
                selected: {feedTab},
                onSelectionChanged: (value) {
                  if (value.isNotEmpty) onFeedTabChanged(value.first);
                },
                showSelectedIcon: false,
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHighest,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                  side: WidgetStatePropertyAll(
                    BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (feedTab == _FeedTab.tape)
            _QuotesList(history: history)
          else
            orderBook.when(
              data: (book) =>
                  _OrderBookCard(book: book, onSelectPrice: onSelectPrice),
              loading: () => const _OrderBookSkeleton(),
              error: (e, _) => _OrderBookError(message: '$e'),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Новая заявка', style: text.titleMedium),
              const SizedBox(width: 6),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.help_outline, size: 20),
                tooltip: 'Что такое заявка?',
                onPressed: () =>
                    context.push('/learn/trading-basics/orderbook'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Рыночная'),
                selected: !isLimit,
                selectedColor: scheme.primary.withValues(alpha: 0.18),
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: text.bodyMedium?.copyWith(
                  color: !isLimit ? scheme.primary : scheme.onSurface,
                ),
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
                onSelected: (v) => onToggleType(false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Лимитная'),
                selected: isLimit,
                selectedColor: scheme.primary.withValues(alpha: 0.18),
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: text.bodyMedium?.copyWith(
                  color: isLimit ? scheme.primary : scheme.onSurface,
                ),
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
                onSelected: (v) => onToggleType(true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Количество',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceController,
            enabled: isLimit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Цена (для лимитной)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: submitting ? null : () => onSubmit(OrderSide.buy),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: submitting
                      ? const Text('Отправка...')
                      : const Text('Купить'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: submitting ? null : () => onSubmit(OrderSide.sell),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.sell),
                  label: submitting
                      ? const Text('Отправка...')
                      : const Text('Продать'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandleChart extends StatefulWidget {
  const _CandleChart({required this.data, required this.scheme});
  final List<Candle> data;
  final ColorScheme scheme;

  @override
  State<_CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<_CandleChart> {
  Candle? _selectedCandle;

  @override
  void didUpdateWidget(_CandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если свеча была выбрана, обновляем её данные при изменении widget.data
    if (_selectedCandle != null) {
      final updatedCandle = widget.data.firstWhere(
        (c) =>
            c.ts.millisecondsSinceEpoch ==
            _selectedCandle!.ts.millisecondsSinceEpoch,
        orElse: () => _selectedCandle!,
      );
      if (updatedCandle != _selectedCandle) {
        setState(() {
          _selectedCandle = updatedCandle;
        });
      }
    }
  }

  void _handleTap(TapDownDetails details) {
    if (widget.data.isEmpty) return;

    const paddingLeft = 48.0;
    const paddingRight = 12.0;
    final chartWidth = context.size!.width - paddingLeft - paddingRight;

    final tapX = details.localPosition.dx - paddingLeft;

    // Если нажали вне графика, показываем последнюю свечу
    if (tapX < 0 || tapX > chartWidth) {
      setState(() {
        _selectedCandle = widget.data.last;
      });
      return;
    }

    final candleWidth = chartWidth / widget.data.length;
    final index = (tapX / candleWidth).floor();

    if (index >= 0 && index < widget.data.length) {
      setState(() {
        _selectedCandle = widget.data[index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCandle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Макс: ${_selectedCandle!.high.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Мин: ${_selectedCandle!.low.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _selectedCandle = null),
                ),
              ],
            ),
          ),
        Expanded(
          child: GestureDetector(
            onTapDown: _handleTap,
            child: CustomPaint(
              painter: _CandlePainter(
                data: widget.data,
                scheme: widget.scheme,
                selectedCandle: _selectedCandle,
              ),
              child: Container(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.data,
    required this.scheme,
    this.selectedCandle,
  });
  final List<Candle> data;
  final ColorScheme scheme;
  final Candle? selectedCandle;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final valid = data.where((c) => c.isValid).toList();
    if (valid.isEmpty) return;

    const paddingLeft = 48.0;
    const paddingRight = 12.0;
    const paddingTop = 8.0;
    const paddingBottom = 24.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final lows = valid.map((c) => c.low).toList();
    final highs = valid.map((c) => c.high).toList();
    final minP = lows.reduce((a, b) => a < b ? a : b);
    final maxP = highs.reduce((a, b) => a > b ? a : b);

    // Добавляем отступы сверху и снизу (10% от диапазона)
    final rawRange = (maxP - minP).abs();
    final padding = rawRange < 1e-9 ? 0.5 : rawRange * 0.1;
    final paddedMin = minP - padding;
    final paddedMax = maxP + padding;
    final range = paddedMax - paddedMin;

    double priceToY(double price) {
      final normalized = (price - paddedMin) / range;
      return paddingTop + chartHeight - normalized * chartHeight;
    }

    final paintWick = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.8)
      ..strokeWidth = 1.4;

    final axisPaint = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // Axes
    final xAxisY = paddingTop + chartHeight;
    canvas.drawLine(
      const Offset(paddingLeft, paddingTop),
      Offset(paddingLeft, xAxisY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(paddingLeft, xAxisY),
      Offset(size.width - paddingRight, xAxisY),
      axisPaint,
    );

    // Y ticks (min, mid, max)
    final yTicks = [paddedMin, paddedMin + range / 2, paddedMax];
    for (final value in yTicks) {
      final y = priceToY(value);
      canvas.drawLine(
        Offset(paddingLeft - 4, y),
        Offset(paddingLeft, y),
        axisPaint,
      );
      final textSpan = TextSpan(
        text: value.toStringAsFixed(2),
        style: labelStyle,
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 8, y - tp.height / 2));
    }

    // X ticks (start/end time)
    String fmtTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    const firstX = paddingLeft;
    final lastX = paddingLeft + chartWidth;
    final firstLabel = fmtTime(valid.first.ts);
    final lastLabel = fmtTime(valid.last.ts);
    final firstTp = TextPainter(
      text: TextSpan(text: firstLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final lastTp = TextPainter(
      text: TextSpan(text: lastLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    firstTp.paint(canvas, Offset(firstX, xAxisY + 4));
    lastTp.paint(canvas, Offset(lastX - lastTp.width, xAxisY + 4));

    // Candles
    final candleWidth = chartWidth / (valid.length * 1.1);
    final space = candleWidth * 0.1;
    for (var i = 0; i < valid.length; i++) {
      final c = valid[i];
      final x = paddingLeft + i * (candleWidth + space) + candleWidth / 2;

      // Подсветка выбранной свечи
      final isSelected =
          selectedCandle != null &&
          c.ts.millisecondsSinceEpoch ==
              selectedCandle!.ts.millisecondsSinceEpoch;

      if (isSelected) {
        final highlightPaint = Paint()
          ..color = scheme.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(
            x - candleWidth / 2 - 2,
            paddingTop,
            candleWidth + 4,
            chartHeight,
          ),
          highlightPaint,
        );
      }

      // Wick
      canvas.drawLine(
        Offset(x, priceToY(c.high)),
        Offset(x, priceToY(c.low)),
        paintWick,
      );

      final isUp = c.close >= c.open;
      final bodyPaint = Paint()
        ..color = isUp
            ? AppColors.success
            : AppColors.error.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      final top = priceToY(isUp ? c.close : c.open);
      final bottom = priceToY(isUp ? c.open : c.close);
      final rect = Rect.fromLTWH(
        x - candleWidth / 2,
        top,
        candleWidth,
        (bottom - top).abs().clamp(1.0, chartHeight),
      );
      canvas.drawRect(rect, bodyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _QuotesList extends StatelessWidget {
  const _QuotesList({required this.history});
  final List<MarketPrice> history;

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.take(5).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: reversed.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = reversed[index];
          final time = item.ts.toLocal();
          final timeStr =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
          return ListTile(
            dense: true,
            title: Text(item.price.toStringAsFixed(2)),
            subtitle: Text(timeStr),
          );
        },
      ),
    );
  }
}

class _OrderBookCard extends StatelessWidget {
  const _OrderBookCard({required this.book, required this.onSelectPrice});

  final OrderBook? book;
  final ValueChanged<double> onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final asks = (book?.asks ?? const <OrderBookLevel>[]).take(8).toList();
    final bids = (book?.bids ?? const <OrderBookLevel>[]).take(8).toList();
    final maxVolume = [
      ...asks.map((e) => e.volume.abs()),
      ...bids.map((e) => e.volume.abs()),
    ].fold<double>(0, (p, v) => v > p ? v : p);
    final label = book == null
        ? 'ждём первую пачку...'
        : 'обновлено в ${TimeOfDay.fromDateTime(book!.ts).format(context)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Стакан',
                    style: text.labelMedium?.copyWith(color: scheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _OrderBookSide(
                    title: 'Покупка',
                    isAsk: false,
                    levels: bids,
                    maxVolume: maxVolume,
                    onSelectPrice: onSelectPrice,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _OrderBookSide(
                    title: 'Продажа',
                    isAsk: true,
                    levels: asks,
                    maxVolume: maxVolume,
                    onSelectPrice: onSelectPrice,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderBookSide extends StatelessWidget {
  const _OrderBookSide({
    required this.title,
    required this.isAsk,
    required this.levels,
    required this.maxVolume,
    required this.onSelectPrice,
  });

  final String title;
  final bool isAsk;
  final List<OrderBookLevel> levels;
  final double maxVolume;
  final ValueChanged<double> onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = isAsk ? AppColors.error : AppColors.success;
    return Column(
      crossAxisAlignment: isAsk
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isAsk
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              isAsk ? Icons.north_east : Icons.south_west,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(title, style: text.labelMedium?.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 8),
        if (levels.isEmpty)
          Text(
            'нет заявок',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          ...levels.map(
            (level) => _OrderBookRow(
              level: level,
              isAsk: isAsk,
              maxVolume: maxVolume <= 0 ? 1 : maxVolume,
              color: color,
              onSelectPrice: onSelectPrice,
            ),
          ),
      ],
    );
  }
}

class _OrderBookRow extends StatelessWidget {
  const _OrderBookRow({
    required this.level,
    required this.isAsk,
    required this.maxVolume,
    required this.color,
    required this.onSelectPrice,
  });

  final OrderBookLevel level;
  final bool isAsk;
  final double maxVolume;
  final Color color;
  final ValueChanged<double> onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = (level.volume / maxVolume).clamp(0.12, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onSelectPrice(level.price),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Align(
              alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                alignment: isAsk ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: isAsk
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (!isAsk) ...[
                    Text(
                      level.price.toStringAsFixed(2),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${level.volume.toStringAsFixed(0)} лотов',
                      style: text.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      '${level.volume.toStringAsFixed(0)} лотов',
                      style: text.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      level.price.toStringAsFixed(2),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderBookSkeleton extends StatelessWidget {
  const _OrderBookSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            6,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderBookError extends StatelessWidget {
  const _OrderBookError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
