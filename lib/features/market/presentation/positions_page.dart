import 'package:aloria/core/utils/layout_utils.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:aloria/features/learning_mode/presentation/explainable.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/presentation/positions/top_up_page.dart';
import 'package:aloria/features/market/presentation/positions/widgets/orders_list_section.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_hero.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_tabs_header.dart';
import 'package:aloria/features/market/presentation/positions/widgets/portfolio_title_bar.dart';
import 'package:aloria/features/market/presentation/positions/widgets/positions_list_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Страница «Портфель»: hero-карточка с оценкой и распределением,
/// вкладки «Позиции / Заявки» и соответствующий список.
class PositionsPage extends ConsumerWidget {
  const PositionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(positionsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final orders = ref.watch(ordersProvider);
    final auth = ref.read(authControllerProvider.notifier);

    // Как только видим хотя бы одну ненулевую позицию — отправляем
    // событие «первая сделка» в aloria-api. Бэкенд идемпотентен,
    // повторные вызовы безопасны (UNIQUE индекс по userId+code).
    ref.listen<AsyncValue<List<Position>>>(positionsProvider, (prev, next) {
      next.whenData((list) {
        final hasPosition = list.any((p) => p.quantity != 0);
        if (!hasPosition) return;
        final portfolioId = ref.read(aloriaPortfolioIdProvider);
        final client = ref.read(learningApiClientProvider);
        // Огонь и забыли: ошибки сети не должны ломать UI.
        client.reportFirstPosition(portfolioId).catchError((_) {});
      });
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _PositionsBlock(
          positions: positions,
          summary: summary,
          orders: orders,
          onLogout: auth.logout,
        ),
      ),
    );
  }
}

class _PositionsBlock extends ConsumerStatefulWidget {
  const _PositionsBlock({
    required this.positions,
    required this.summary,
    required this.orders,
    required this.onLogout,
  });
  final AsyncValue<List<Position>> positions;
  final AsyncValue<PortfolioSummary> summary;
  final AsyncValue<List<ClientOrder>> orders;
  final Future<void> Function() onLogout;

  @override
  ConsumerState<_PositionsBlock> createState() => _PositionsBlockState();
}

class _PositionsBlockState extends ConsumerState<_PositionsBlock>
    with TickerProviderStateMixin {
  Future<void> _openTopUp() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TopUpPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(portfolioTabProvider);

    final positionsCount = widget.positions.maybeWhen(
      data: (l) => l.where((p) => p.quantity != 0).length,
      orElse: () => 0,
    );
    final activeOrdersCount = widget.orders.maybeWhen(
      data: (l) => l.where((o) => o.isActive).length,
      orElse: () => 0,
    );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, context.bottomNavBarPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const PortfolioTitleBar(),
              const SizedBox(height: 12),
              Explainable(
                slug: 'portfolio.hero',
                borderRadius: BorderRadius.circular(20),
                child: PortfolioHero(
                  summary: widget.summary,
                  positions: widget.positions,
                  onTopUp: _openTopUp,
                ),
              ),
              const SizedBox(height: 18),
              Explainable(
                slug: 'portfolio.tabs',
                borderRadius: BorderRadius.circular(8),
                child: PortfolioTabsHeader(
                  selected: tab,
                  positionsCount: positionsCount,
                  ordersCount: activeOrdersCount,
                  onSelected: (next) {
                    ref.read(portfolioTabProvider.notifier).state = next;
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (tab == PortfolioTab.positions)
                PositionsListSection(positions: widget.positions)
              else
                OrdersListSection(orders: widget.orders),
            ]),
          ),
        ),
      ],
    );
  }
}
