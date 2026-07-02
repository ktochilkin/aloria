import 'package:aloria/core/theme/tokens.dart';
import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/market/application/market_controller.dart';
import 'package:aloria/features/market/application/market_news_provider.dart';
import 'package:aloria/features/market/data/market_macro_repository.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:aloria/features/market/presentation/numeric_text.dart';
import 'package:aloria/features/market/presentation/widgets/aloria_index_card.dart';
import 'package:aloria/features/market/presentation/widgets/how_market_works_page.dart';
import 'package:aloria/features/market/presentation/widgets/instrument_avatar.dart';
import 'package:aloria/features/market/presentation/widgets/macro_card.dart';
import 'package:aloria/features/market/presentation/widgets/macro_detail_page.dart';
import 'package:aloria/features/market/presentation/widgets/news_detail_modal.dart';
import 'package:aloria/features/market/presentation/widgets/news_meta.dart';
import 'package:aloria/features/market/presentation/widgets/upcoming_events.dart';
import 'package:animations/animations.dart';
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
    final asyncMacro = ref.watch(macroStateProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(76),
            child: Builder(
              builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                final text = Theme.of(context).textTheme;
                final controller = DefaultTabController.of(context);

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
              asyncMacro: asyncMacro,
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
    required this.asyncMacro,
  });

  final AsyncValue<List<MarketSecurity>> asyncSecurities;
  final AsyncValue<MacroState> asyncMacro;

  @override
  Widget build(BuildContext context) {
    return asyncSecurities.when(
      data: (items) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final priced = items
            .where((s) => s.changePercent != null)
            .toList(growable: false);
        final macro = asyncMacro.valueOrNull;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(
                child: _MacroSection(asyncMacro: asyncMacro),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              sliver: SliverToBoxAdapter(
                child: AloriaIndexCard(securities: items),
              ),
            ),
            if (macro != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                sliver: SliverToBoxAdapter(
                  child: UpcomingEvents(macro: macro, securities: items),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(child: _HowItWorksCard()),
            ),
            if (priced.length >= 3)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                sliver: SliverToBoxAdapter(
                  child: _MoversStrip(securities: priced),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _InstrumentClassFilter()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];
                  final label = item.symbol.length > 2
                      ? item.symbol.substring(0, 2)
                      : item.symbol;
                  final isLast = index == items.length - 1;

                  return Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            context.push('/market/${item.symbol}', extra: item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              InstrumentAvatar(
                                symbol: item.symbol,
                                label: label,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.symbol,
                                      style: text.titleMedium?.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
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
                                      style: monoNum(size: 16),
                                    ),
                                    if (item.changePercent != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.changePercent! >= 0 ? '+' : ''}${item.changePercent!.toStringAsFixed(2)}%',
                                        style: monoNum(
                                          size: 13,
                                          color: item.changePercent! >= 0
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.outline.withValues(alpha: 0.22),
                        ),
                    ],
                  );
                }, childCount: items.length),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                context.bottomNavBarPadding,
              ),
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

class _MarketNewsTab extends ConsumerWidget {
  const _MarketNewsTab({required this.asyncNews});

  final AsyncValue<List<MarketNews>> asyncNews;

  // Секции ленты: заголовок + предикат типа события. Пустые секции скрываются;
  // «Облигации»/«Новости по секторам» появятся, когда их наполнит ИИ-режиссёр.
  static final List<({String title, bool Function(MarketNews) test})>
  _sections = [
    (title: 'Макроэкономика', test: (n) => n.eventType == 'macro'),
    (
      title: 'Дивиденды и купоны',
      test: (n) => n.eventType == 'dividend' || n.eventType == 'coupon',
    ),
    (title: 'Отчётность компаний', test: (n) => n.eventType == 'earnings'),
    (
      title: 'Корпоративные новости',
      test: (n) =>
          n.eventType == 'guidance' ||
          n.eventType == 'operations' ||
          n.eventType == 'product',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncNews.when(
      data: (all) {
        if (all.isEmpty) {
          return const Center(child: Text('Новости отсутствуют'));
        }

        final sorted = [...all]
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        final hero = sorted.first;
        final rest = sorted.skip(1).toList();
        final sections = _sections
            .map((s) => (title: s.title, items: rest.where(s.test).toList()))
            .where((s) => s.items.isNotEmpty)
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(marketAllNewsProvider);
            await ref.read(marketAllNewsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 12, 0, context.bottomNavBarPadding),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _HeroNewsCard(news: hero),
              ),
              for (final s in sections) ...[
                _NewsSection(title: s.title, items: s.items),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Не удалось загрузить новости: $e')),
    );
  }
}

/// Герой-карточка: последняя новость мира крупно, с тональной подложкой.
class _HeroNewsCard extends StatelessWidget {
  const _HeroNewsCard({required this.news});

  final MarketNews news;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = newsSentimentColor(news.sentiment);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => showNewsDetailModal(context, news),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outline),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tone.withValues(alpha: 0.14), scheme.surface],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Последняя',
                        style: text.labelSmall?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: NewsMetaRow(news: news)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  news.title,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  news.content,
                  style: text.bodyMedium?.copyWith(height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      formatNewsDate(news.publishedAt),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Читать',
                      style: text.labelLarge?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: tone),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsSection extends StatelessWidget {
  const _NewsSection({required this.title, required this.items});

  final String title;
  final List<MarketNews> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _NewsCardCompact(news: items[i]),
          ),
        ),
      ],
    );
  }
}

class _NewsCardCompact extends StatelessWidget {
  const _NewsCardCompact({required this.news});

  final MarketNews news;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final tone = newsSentimentColor(news.sentiment);

    return SizedBox(
      width: 290,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showNewsDetailModal(context, news),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 4, color: tone.withValues(alpha: 0.75)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NewsMetaRow(news: news),
                      const SizedBox(height: 8),
                      Text(
                        news.title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          news.content,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatNewsDate(news.publishedAt),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacroSection extends StatelessWidget {
  const _MacroSection({required this.asyncMacro});

  final AsyncValue<MacroState> asyncMacro;

  @override
  Widget build(BuildContext context) {
    return asyncMacro.when(
      data: (state) {
        final scheme = Theme.of(context).colorScheme;
        // Повторяем штатный CardTheme (плоская, радиус 24, обводка outline),
        // чтобы закрытое состояние выглядело как обычная карточка.
        return OpenContainer(
          transitionType: ContainerTransitionType.fadeThrough,
          transitionDuration: const Duration(milliseconds: 420),
          closedElevation: 0,
          closedColor: scheme.surface,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: scheme.outline),
          ),
          openColor: scheme.surface,
          closedBuilder: (context, open) =>
              MacroCard(state: state, useCard: false, onTap: open),
          openBuilder: (context, _) => MacroDetailPage(state: state),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Не удалось загрузить макроданные: $e'),
        ),
      ),
    );
  }
}

/// Фильтр по классу инструмента. Пока чисто визуальный (без логики) — список
/// инструментов не фильтруется, привяжем при появлении облигаций/фондов.
class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openHowMarketWorks(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Как устроен рынок Aloria',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Коротко о том, что двигает цены',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrumentClassFilter extends StatefulWidget {
  const _InstrumentClassFilter();

  @override
  State<_InstrumentClassFilter> createState() => _InstrumentClassFilterState();
}

class _InstrumentClassFilterState extends State<_InstrumentClassFilter> {
  int _selected = 0;
  static const _classes = ['Все', 'Акции', 'Облигации', 'Фонды', 'Валюта'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _classes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(_classes[i]),
          selected: _selected == i,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _selected = i),
        ),
      ),
    );
  }
}

/// Лидеры дня: топ роста и падения из реальных котировок (changePercent).
class _MoversStrip extends StatelessWidget {
  const _MoversStrip({required this.securities});

  final List<MarketSecurity> securities;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sorted = [...securities]
      ..sort((a, b) => (b.changePercent ?? 0).compareTo(a.changePercent ?? 0));
    final gainers = sorted.where((s) => (s.changePercent ?? 0) > 0).take(3);
    final losers = sorted.reversed
        .where((s) => (s.changePercent ?? 0) < 0)
        .take(3);
    final movers = [...gainers, ...losers];
    if (movers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Лидеры дня',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: movers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _MoverCard(security: movers[i]),
          ),
        ),
      ],
    );
  }
}

class _MoverCard extends StatelessWidget {
  const _MoverCard({required this.security});

  final MarketSecurity security;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ch = security.changePercent ?? 0;
    final up = ch >= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/market/${security.symbol}', extra: security),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              security.symbol,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (security.lastPrice != null) ...[
                  Text(
                    security.lastPrice!.toStringAsFixed(2),
                    style: monoNum(size: 13),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${up ? '+' : ''}${ch.toStringAsFixed(2)}%',
                  style: monoNum(
                    size: 13,
                    color: up ? AppColors.success : AppColors.error,
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
