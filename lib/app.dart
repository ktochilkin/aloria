import 'package:aloria/app_config.dart';
import 'package:aloria/core/platform/web_scroll_behavior.dart';
import 'package:aloria/core/theme/app_theme.dart';
import 'package:aloria/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AloriaApp extends ConsumerWidget {
  final AppConfig config;
  const AloriaApp({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Aloria (${config.env.name})',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // Оптимизация скроллинга для веб-платформ
      scrollBehavior: kIsWeb ? const WebScrollBehavior() : null,
      // Отключение отладочного баннера
      debugShowCheckedModeBanner: false,
    );
  }
}
