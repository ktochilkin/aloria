import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/widgets/top_notification.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/application/order_book_notifier.dart';
import 'package:aloria/features/market/application/price_feed_notifier.dart';
import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/market/presentation/widgets/news_widget.dart';
import 'package:aloria/features/market/presentation/widgets/order_book_widget.dart';
import 'package:aloria/features/market/presentation/widgets/quotes_list.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _FeedTab { news, tape, orderBook }

final feedTabProvider = StateProvider.family<_FeedTab, String>((ref, symbol) {
  // Сохраняем состояние вкладки, чтобы не сбрасывалось
  ref.keepAlive();
  return _FeedTab.news;
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
        String errorMessage = 'Ошибка отправки';

        // Проверяем, является ли ошибка DioException
        if (e is DioException && e.response != null) {
          final responseData = e.response!.data;
          if (responseData is Map<String, dynamic> &&
              responseData.containsKey('message')) {
            errorMessage = responseData['message'] as String;
          } else {
            errorMessage = 'Ошибка отправки: ${e.response!.statusCode}';
          }
        } else {
          errorMessage = 'Ошибка отправки: $e';
        }

        showTopNotification(context, errorMessage, isError: true);
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
    final news = ref.watch(marketNewsProvider(widget.symbol));
    final feedTab = ref.watch(feedTabProvider(widget.symbol));

    final trimmedShort = widget.shortName.trim();
    final showShort = trimmedShort.isNotEmpty && trimmedShort != widget.symbol;
    final titleText = showShort
        ? '${widget.symbol} · $trimmedShort'
        : widget.symbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: feed.when(
          data: (state) => _TradeBody(
            symbol: widget.symbol,
            state: state,
            orderBook: orderBook,
            news: news,
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
    required this.news,
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
  final AsyncValue<List<MarketNews>> news;
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} сек назад';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    } else {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return 'в $h:$m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = state.latest;
    final history = state.history;
    final candles = state.candles;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
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
                  children: [
                    InstrumentAvatar(
                      symbol: symbol,
                      label: symbol.length > 2
                          ? symbol.substring(0, 2)
                          : symbol,
                      size: 56,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Последняя цена',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latest != null
                                ? '${latest.price.toStringAsFixed(2)} ₽'
                                : '--',
                            style: text.headlineMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (latest != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(latest.ts.toLocal()),
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                    : _CandleChart(data: candles, scheme: scheme),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Пульс рынка', style: text.titleMedium),
                Text(
                  feedTab == _FeedTab.news
                      ? 'Новости и события по инструменту'
                      : feedTab == _FeedTab.tape
                      ? 'Лента последних сделок'
                      : 'Биржевой стакан в реальном времени',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Center(
                  child: SegmentedButton<_FeedTab>(
                    segments: const [
                      ButtonSegment(
                        value: _FeedTab.news,
                        icon: Icon(Icons.article),
                        label: Text('Новости'),
                      ),
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
                        BorderSide(
                          color: scheme.outline.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (feedTab == _FeedTab.news)
              news.when(
                data: (items) => NewsWidget(news: items),
                loading: () => const Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Не удалось загрузить новости: $e'),
                  ),
                ),
              ),
            if (feedTab == _FeedTab.tape) QuotesList(history: history),
            if (feedTab == _FeedTab.orderBook)
              orderBook.when(
                data: (book) =>
                    OrderBookWidget(book: book, onSelectPrice: onSelectPrice),
                loading: () => const OrderBookSkeleton(),
                error: (e, _) => OrderBookError(message: '$e'),
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
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
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
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.6),
                  ),
                  onSelected: (v) => onToggleType(true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                if (isLimit) {
                  FocusScope.of(context).nextFocus();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              enabled: isLimit,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                    onPressed: submitting
                        ? null
                        : () => onSubmit(OrderSide.buy),
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
                    onPressed: submitting
                        ? null
                        : () => onSubmit(OrderSide.sell),
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

  String _formatCandleTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
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
        if (_selectedCandle != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Данные свечи',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: widget.scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _selectedCandle = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CandleDataRow(
                  label: 'Цена на начало периода',
                  value: '${_selectedCandle!.open.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Цена на конец периода',
                  value: '${_selectedCandle!.close.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Максимальная цена',
                  value: '${_selectedCandle!.high.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.success,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Минимальная цена',
                  value: '${_selectedCandle!.low.toStringAsFixed(2)} ₽',
                  scheme: widget.scheme,
                  valueColor: AppColors.error,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Количество сделок',
                  value: _selectedCandle!.volume.toString(),
                  scheme: widget.scheme,
                ),
                const SizedBox(height: 6),
                _CandleDataRow(
                  label: 'Время свечи',
                  value: _formatCandleTime(_selectedCandle!.ts),
                  scheme: widget.scheme,
                ),
              ],
            ),
          ),
        ],
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

class _CandleDataRow extends StatelessWidget {
  const _CandleDataRow({
    required this.label,
    required this.value,
    required this.scheme,
    this.valueColor,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
