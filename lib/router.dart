import 'dart:async';

import 'package:aloria/core/env/env.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/auth/presentation/login_page.dart';
import 'package:aloria/features/learn/presentation/learning_page.dart';
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
      ShellRoute(
        builder: (context, state, child) =>
            _NavShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/learn',
            name: 'learn',
            builder: (ctx, state) => const LearningPage(),
          ),
          GoRoute(
            path: '/learn/:sectionId',
            name: 'learn_section',
            builder: (ctx, state) {
              final sectionId = state.pathParameters['sectionId']!;
              final section = findSectionById(sectionId);
              if (section == null) {
                return const _MissingRoutePage(message: 'Раздел не найден');
              }
              return LearningSectionPage(section: section);
            },
          ),
          GoRoute(
            path: '/learn/:sectionId/:lessonId',
            name: 'learn_lesson',
            builder: (ctx, state) {
              final sectionId = state.pathParameters['sectionId']!;
              final lessonId = state.pathParameters['lessonId']!;
              final section = findSectionById(sectionId);
              final lesson = section == null
                  ? null
                  : findLessonById(section, lessonId);
              if (section == null || lesson == null) {
                return const _MissingRoutePage(message: 'Урок не найден');
              }
              return LessonPage(section: section, lesson: lesson);
            },
          ),
          GoRoute(
            path: '/positions',
            name: 'positions',
            builder: (ctx, state) => const PositionsPage(),
          ),
          GoRoute(
            path: '/market',
            name: 'market',
            builder: (ctx, state) => const MarketPage(),
          ),
          GoRoute(
            path: '/market/:symbol',
            name: 'market_trade',
            builder: (ctx, state) {
              final symbol = state.pathParameters['symbol']!;
              final security = state.extra;
              final shortName = security is MarketSecurity
                  ? security.shortName
                  : symbol;
              final exchange = security is MarketSecurity
                  ? security.exchange
                  : 'MOEX';
              return TradePage(
                symbol: symbol,
                shortName: shortName,
                exchange: exchange,
              );
            },
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

final lastMarketLocationProvider = StateProvider<String>((_) => '/market');
final lastLearningLocationProvider = StateProvider<String>((_) => '/learn');

class _NavShell extends ConsumerWidget {
  const _NavShell({required this.child, required this.location});

  final Widget child;
  final String location;

  static const _tabs = [
    _NavTab(label: 'Обучение', icon: Icons.school, route: '/learn'),
    _NavTab(label: 'Портфель', icon: Icons.list_alt, route: '/positions'),
    _NavTab(label: 'Обзор рынка', icon: Icons.show_chart, route: '/market'),
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/market')) return 2;
    if (location.startsWith('/positions')) return 1;
    return 0;
  }

  void _goAndRestoreStack(
    BuildContext context, {
    required String baseRoute,
    required String lastRoute,
  }) {
    context.go(baseRoute);
    if (lastRoute == baseRoute) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.push(lastRoute);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep positions stream connected even when tab not visible.
    ref.read(positionsBootstrapperProvider);
    ref.read(portfolioSummaryBootstrapperProvider);
    if (location.startsWith('/learn')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastLearningLocationProvider.notifier).state = location;
      });
    }
    if (location.startsWith('/market')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastMarketLocationProvider.notifier).state = location;
      });
    }
    final index = _indexForLocation(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == 0) {
            final lastLearning = ref.read(lastLearningLocationProvider);
            if (location.startsWith('/learn')) {
              if (location != lastLearning) {
                // Already inside learning; keep current location.
                ref.read(lastLearningLocationProvider.notifier).state =
                    location;
              }
              return;
            }
            _goAndRestoreStack(
              context,
              baseRoute: '/learn',
              lastRoute: lastLearning,
            );
            return;
          }
          if (i == 2) {
            final lastMarket = ref.read(lastMarketLocationProvider);
            // If already on a market screen, a tab tap returns to the list.
            if (location.startsWith('/market')) {
              if (location != '/market') context.go('/market');
              return;
            }
            _goAndRestoreStack(
              context,
              baseRoute: '/market',
              lastRoute: lastMarket,
            );
            return;
          }
          final target = _tabs[i].route;
          if (target != location) context.go(target);
        },
        destinations: _tabs
            .map(
              (t) => NavigationDestination(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
      ),
    );
  }
}

class _MissingRoutePage extends StatelessWidget {
  const _MissingRoutePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Не найдено')),
      body: Center(child: Text(message)),
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

class _NavTab {
  const _NavTab({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}
