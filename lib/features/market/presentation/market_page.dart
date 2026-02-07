import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/market/presentation/widgets/news_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});

  static const _tabs = [_MarketTab.overview, _MarketTab.news];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSecurities = ref.watch(marketSecuritiesProvider);
    final asyncNews = ref.watch(marketAllNewsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: null,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                final text = Theme.of(context).textTheme;
                final controller = DefaultTabController.of(context);

                if (controller == null) return const SizedBox.shrink();

                return AnimatedBuilder(
                  animation: controller.animation ?? controller,
                  builder: (context, _) {
                    final animationValue =
                        controller.animation?.value ??
                        controller.index.toDouble();
                    final clampedIndex = animationValue
                        .clamp(0, (_tabs.length - 1).toDouble())
                        .round();
                    final selected = _tabs[clampedIndex];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_MarketTab>(
                          segments: const [
                            ButtonSegment(
                              value: _MarketTab.overview,
                              icon: Icon(Icons.grid_view_rounded),
                              label: Text('Обзор рынка'),
                            ),
                            ButtonSegment(
                              value: _MarketTab.news,
                              icon: Icon(Icons.article_outlined),
                              label: Text('Новости'),
                            ),
                          ],
                          selected: {selected},
                          onSelectionChanged: (value) {
                            if (value.isNotEmpty) {
                              controller.animateTo(_tabs.indexOf(value.first));
                            }
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                            ),
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
                            textStyle: WidgetStatePropertyAll(
                              text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            elevation: const WidgetStatePropertyAll(0),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _MarketOverviewTab(
              asyncSecurities: asyncSecurities,
              asyncNews: asyncNews,
            ),
            _MarketNewsTab(asyncNews: asyncNews),
          ],
        ),
      ),
    );
  }
}

enum _MarketTab { overview, news }

class _MarketOverviewTab extends StatelessWidget {
  const _MarketOverviewTab({
    required this.asyncSecurities,
    required this.asyncNews,
  });

  final AsyncValue<List<MarketSecurity>> asyncSecurities;
  final AsyncValue<List<MarketNews>> asyncNews;

  @override
  Widget build(BuildContext context) {
    return asyncSecurities.when(
      data: (items) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _MarketNewsSection(asyncNews: asyncNews),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) return const SizedBox(height: 12);

                  final itemIndex = index ~/ 2;
                  final item = items[itemIndex];
                  final label = item.symbol.length > 2
                      ? item.symbol.substring(0, 2)
                      : item.symbol;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.surface.withValues(alpha: 0.96),
                          scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          context.push('/market/${item.symbol}', extra: item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            InstrumentAvatar(
                              symbol: item.symbol,
                              label: label,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.symbol, style: text.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.shortName,
                                    style: text.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (item.lastPrice != null) ...[
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item.lastPrice!.toStringAsFixed(2),
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.changePercent != null)
                                    Text(
                                      '${item.changePercent! >= 0 ? '+' : ''}${item.changePercent!.toStringAsFixed(2)}%',
                                      style: text.bodySmall?.copyWith(
                                        color: item.changePercent! >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            Icon(
                              Icons.chevron_right,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: items.isEmpty ? 0 : (items.length * 2 - 1)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _MarketNewsTab extends StatelessWidget {
  const _MarketNewsTab({required this.asyncNews});

  final AsyncValue<List<MarketNews>> asyncNews;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return asyncNews.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Новости отсутствуют'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final news = items[index];

            return Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showFullNews(context, news),
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
                              'Новости',
                              style: text.labelMedium?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _formatDate(news.publishedAt),
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        news.title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news.content,
                        style: text.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Не удалось загрузить новости: $e')),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    }
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _showFullNews(BuildContext context, MarketNews news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      news.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(news.publishedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      news.content,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketNewsSection extends StatelessWidget {
  const _MarketNewsSection({required this.asyncNews});

  final AsyncValue<List<MarketNews>> asyncNews;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        asyncNews.when(
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Новости отсутствуют'),
                ),
              );
            }
            return NewsWidget(news: items);
          },
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
      ],
    );
  }
}
