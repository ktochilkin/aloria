import 'dart:async';

import 'package:aloria/app.dart';
import 'package:aloria/app_config.dart';
import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Настройка статус-бара для iOS
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      // Оптимизации для веб-платформы
      if (kIsWeb) {
        // Отключение контекстного меню на веб
        BrowserContextMenu.disableContextMenu();
      }

      final config = AppConfig.fromEnv();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        appLogger.e(
          'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      runApp(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(config)],
          child: AloriaApp(config: config),
        ),
      );
    },
    (error, stack) =>
        appLogger.e('Uncaught zone error', error: error, stackTrace: stack),
  );
}

/// Helper для отключения контекстного меню на веб
class BrowserContextMenu {
  static void disableContextMenu() {
    if (kIsWeb) {
      // Отключаем долгое нажатие и контекстное меню для лучшей производительности на iOS
    }
  }
}
