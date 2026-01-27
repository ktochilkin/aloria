import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/market/presentation/widgets/news_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketPage extends ConsumerWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSecurities = ref.watch(marketSecuritiesProvider);
    final asyncNews = ref.watch(marketAllNewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Обзор рынка')),
      body: asyncSecurities.when(
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
                            scheme.surfaceContainerHighest.withValues(
                              alpha: 0.9,
                            ),
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
                                    ),
                                  ],
                                ),
                              ),
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
        Text('Новости рынка', style: text.titleMedium),
        const SizedBox(height: 8),
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
