import 'dart:async';

import 'package:aloria/core/env/env.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/auth/presentation/login_page.dart';
import 'package:aloria/features/learn/presentation/learning_page.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/presentation/market_page.dart';
import 'package:aloria/features/market/presentation/positions_page.dart';
import 'package:aloria/features/market/presentation/trade_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  // Keep a stable router instance; react to auth changes via refreshListenable
  // to avoid losing navigation state on token updates.
  final authNotifier = ref.read(authControllerProvider.notifier);
  final refreshListenable = GoRouterRefreshStream(authNotifier.stream);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (ctx, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Branch 1: Learn
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                name: 'learn',
                builder: (ctx, state) => const LearningPage(),
                routes: [
                  GoRoute(
                    path: ':sectionId',
                    name: 'learn_section',
                    builder: (ctx, state) {
                      final sectionId = state.pathParameters['sectionId']!;
                      return LearningSectionPage(sectionId: sectionId);
                    },
                    routes: [
                      GoRoute(
                        path: ':lessonId',
                        name: 'learn_lesson',
                        builder: (ctx, state) {
                          final sectionId = state.pathParameters['sectionId']!;
                          final lessonId = state.pathParameters['lessonId']!;
                          return LessonPage(
                            sectionId: sectionId,
                            lessonId: lessonId,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Positions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/positions',
                name: 'positions',
                builder: (ctx, state) => const PositionsPage(),
              ),
            ],
          ),
          // Branch 3: Market
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/market',
                name: 'market',
                builder: (ctx, state) => const MarketPage(),
                routes: [
                  GoRoute(
                    path: ':symbol',
                    name: 'market_trade',
                    builder: (ctx, state) {
                      final symbol = state.pathParameters['symbol']!;
                      final security = state.extra;
                      final shortName = security is MarketSecurity
                          ? security.shortName
                          : symbol;
                      final exchange = security is MarketSecurity
                          ? security.exchange
                          : 'TEREX';
                      return TradePage(
                        key: ValueKey('trade_${exchange}_$symbol'),
                        symbol: symbol,
                        shortName: shortName,
                        exchange: exchange,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final tokens = ref.read(authControllerProvider).tokens;
      final loggedIn = tokens != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/positions';
      return null;
    },
    debugLogDiagnostics: config.enableLogging,
  );
});

class _ScaffoldWithNavBar extends ConsumerWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active. This example demonstrates how to support this behavior,
      // using the initialLocation parameter of goBranch.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep positions stream connected even when tab not visible.
    ref.read(positionsBootstrapperProvider);
    ref.read(portfolioSummaryBootstrapperProvider);
    ref.read(ordersBootstrapperProvider);

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    // Для десктопа оборачиваем в контейнер с ограничением ширины
    final scaffold = Scaffold(
      body: SafeArea(
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            label: 'Обучение',
            icon: Icon(Icons.school),
          ),
          NavigationDestination(
            label: 'Портфель',
            icon: Icon(Icons.list_alt),
          ),
          NavigationDestination(
            label: 'Обзор рынка',
            icon: Icon(Icons.show_chart),
          ),
        ],
      ),
    );

    if (isMobile) {
      return scaffold;
    }

    // На десктопе центрируем и ограничиваем ширину
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          child: scaffold,
        ),
      ),
    );
  }
}

/// Minimal replacement for GoRouterRefreshStream (absent in older go_router versions).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
