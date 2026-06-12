import 'dart:async';

import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/push/push_controller.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/auth/presentation/login_page.dart';
import 'package:aloria/features/learn/presentation/learning_page.dart';
import 'package:aloria/features/learning_mode/presentation/learning_mode_banner.dart';
import 'package:aloria/features/market/application/orders_provider.dart';
import 'package:aloria/features/market/application/portfolio_summary_provider.dart';
import 'package:aloria/features/market/application/positions_provider.dart';
import 'package:aloria/features/market/data/market_repository.dart';
import 'package:aloria/features/market/presentation/market_page.dart';
import 'package:aloria/features/market/presentation/positions_page.dart';
import 'package:aloria/features/market/presentation/trade_page.dart';
import 'package:aloria/features/profile/presentation/progress_page.dart';
import 'package:aloria/features/settings/application/settings_controller.dart';
import 'package:aloria/features/settings/presentation/settings_page.dart';
import 'package:aloria/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  // Keep a stable router instance; react to auth changes via refreshListenable
  // to avoid losing navigation state on token updates.
  final authNotifier = ref.read(authControllerProvider.notifier);
  final refreshListenable = GoRouterRefreshStream(authNotifier.stream);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (ctx, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/progress',
        name: 'progress',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (ctx, state) => const ProgressPage(),
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
    // Подсказываем редиректу не пускать /settings без логина:
    // он сам срабатывает по логике выше, дополнительной обработки не нужно.
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
    // Пуши (iOS): инициализация + регистрация токена после логина.
    ref.read(pushBootstrapProvider);
    // Тап по пушу → deep-link на нужный экран.
    ref.listen(pushTapProvider, (_, next) {
      final tap = next.valueOrNull;
      if (tap != null) context.go(tap.route);
    });

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    // Для десктопа оборачиваем в контейнер с ограничением ширины
    final scheme = Theme.of(context).colorScheme;
    final learningOn = ref.watch(
      settingsControllerProvider.select((s) => s.learningMode),
    );
    final scaffold = Scaffold(
      body: Column(
        children: [
          const LearningModeBanner(),
          Expanded(
            // Когда показана плашка обучения, она уже сдвигает контент вниз
            // (внутри есть SafeArea для статус-бара). Отключаем «второй»
            // SafeArea внутри самих страниц, чтобы не было двойного отступа.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: learningOn,
              child: navigationShell,
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goBranch,
              destinations: [
                NavigationDestination(
                  label: AppLocalizations.of(context)!.navLearn,
                  icon: const Icon(Icons.school),
                ),
                NavigationDestination(
                  label: AppLocalizations.of(context)!.navPortfolio,
                  icon: const Icon(Icons.list_alt),
                ),
                NavigationDestination(
                  label: AppLocalizations.of(context)!.navMarket,
                  icon: const Icon(Icons.show_chart),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (isMobile) {
      return scaffold;
    }

    // На десктопе центрируем и ограничиваем ширину
    return ColoredBox(
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
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
