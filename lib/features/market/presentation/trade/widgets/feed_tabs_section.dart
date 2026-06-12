import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/presentation/trade/trade_providers.dart';
import 'package:aloria/features/market/presentation/widgets/news_widget.dart';
import 'package:aloria/features/market/presentation/widgets/order_book_widget.dart';
import 'package:aloria/features/market/presentation/widgets/quotes_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Блок «Пульс рынка»: переключатель Новости / Лента / Стакан и
/// соответствующее содержимое.
class FeedTabsSection extends StatelessWidget {
  const FeedTabsSection({
    super.key,
    required this.feedTab,
    required this.onFeedTabChanged,
    required this.news,
    required this.history,
    required this.orderBook,
    required this.onSelectPrice,
  });

  /// Активная вкладка.
  final FeedTab feedTab;

  /// Колбэк выбора вкладки.
  final ValueChanged<FeedTab> onFeedTabChanged;

  /// Новости по инструменту.
  final AsyncValue<List<MarketNews>> news;

  /// История котировок (лента сделок).
  final List<MarketPrice> history;

  /// Стакан.
  final AsyncValue<OrderBook?> orderBook;

  /// Выбор цены из стакана (подставляется в лимитную заявку).
  final ValueChanged<double> onSelectPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Выравнивание повторяет родительскую колонку TradeBody (start),
    // чтобы вынос секции не менял раскладку.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Пульс рынка', style: text.titleMedium),
            const SizedBox(height: 2),
            Text(
              feedTab == FeedTab.news
                  ? 'Новости и события по инструменту'
                  : feedTab == FeedTab.tape
                  ? 'Лента последних сделок'
                  : 'Биржевой стакан в реальном времени',
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<FeedTab>(
              expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(
                    value: FeedTab.news,
                    icon: Icon(Icons.article),
                    label: Text('Новости'),
                  ),
                  ButtonSegment(
                    value: FeedTab.tape,
                    icon: Icon(Icons.bolt),
                    label: Text('Лента'),
                  ),
                  ButtonSegment(
                    value: FeedTab.orderBook,
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
          ],
        ),
        const SizedBox(height: 8),
        if (feedTab == FeedTab.news)
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
        if (feedTab == FeedTab.tape) QuotesList(history: history),
        if (feedTab == FeedTab.orderBook)
          orderBook.when(
            data: (book) =>
                OrderBookWidget(book: book, onSelectPrice: onSelectPrice),
            loading: () => const OrderBookSkeleton(),
            error: (e, _) => OrderBookError(message: '$e'),
          ),
      ],
    );
  }
}
