import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/core/push/fcm_push_service.dart';
import 'package:aloria/core/push/push_categories.dart';
import 'package:aloria/core/push/push_service.dart';
import 'package:aloria/core/storage/storage_factory.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/learn/data/learning_api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Подключён ли push-канал на текущей платформе. Пока только iOS —
/// Android/Web подключим, когда добавим их Firebase-конфиги.
bool get isPushPlatformReady =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Push-канал. Сейчас FCM; за интерфейсом [PushService] можно сменить транспорт.
final pushServiceProvider = Provider<PushService>((ref) {
  final service = FcmPushService();
  ref.onDispose(service.dispose);
  return service;
});

final pushControllerProvider = Provider<PushController>(
  (ref) => PushController(ref),
);

/// Поток тапов по уведомлению — для deep-link. Шелл навигации слушает его и
/// переходит на нужный маршрут (держим здесь, чтобы не было цикла с router.dart).
final pushTapProvider = StreamProvider<PushTap>(
  (ref) => ref.watch(pushServiceProvider).onMessageTap,
);

/// Запуск пушей. Вызывается из shell после логина.
final pushBootstrapProvider = Provider<void>((ref) {
  if (!isPushPlatformReady) return;
  Future.microtask(() => ref.read(pushControllerProvider).startAndRegister());
});

/// Оркестратор: инициализация канала, запрос разрешения, регистрация токена на
/// бэке и его обновление при ротации.
class PushController {
  PushController(this._ref);

  final Ref _ref;
  bool _started = false;

  Future<void> startAndRegister() async {
    if (_started) return;
    _started = true;
    final push = _ref.read(pushServiceProvider);
    try {
      await push.init();
      push.onTokenRefresh.listen(_register);

      final granted = await push.requestPermission();
      if (!granted) {
        appLogger.d('push: разрешение не выдано');
        return;
      }
      final token = await push.currentToken();
      if (token != null && token.isNotEmpty) {
        await _register(token);
      }
    } catch (e, s) {
      appLogger.w('push: не удалось инициализировать', error: e, stackTrace: s);
    }
  }

  Future<void> _register(String token) async {
    try {
      final client = _ref.read(learningApiClientProvider);
      final portfolioId = _ref.read(aloriaPortfolioIdProvider);
      await client.registerDevice(
        token: token,
        platform: _platform(),
        portfolioId: portfolioId,
        categories: await _currentCategoriesMask(),
      );
      appLogger.d('push: токен зарегистрирован');
    } catch (e) {
      // best-effort: регистрацию повторим при следующем запуске/ротации токена.
      appLogger.w('push: регистрация токена не удалась: $e');
    }
  }

  /// Отправляет на бэк маску категорий для текущего токена устройства.
  /// Best-effort: без сети маска останется локальной и уедет при следующей
  /// регистрации токена (startAndRegister передаёт её всегда).
  Future<void> syncCategories(int mask) async {
    if (!isPushPlatformReady) return;
    try {
      final token = await _ref.read(pushServiceProvider).currentToken();
      if (token == null || token.isEmpty) return;
      await _ref.read(learningApiClientProvider).updateDeviceCategories(
            token: token,
            categories: mask,
          );
      appLogger.d('push: маска категорий синхронизирована');
    } catch (e) {
      // Ошибку глотаем: UI уже переключился, локальная копия сохранена.
      appLogger.w('push: не удалось синхронизировать категории: $e');
    }
  }

  /// Локальная маска категорий (дефолт контракта — если ещё не сохраняли).
  Future<int> _currentCategoriesMask() async {
    final storage = await _ref.read(storageProvider.future);
    final raw = await storage.read(PushCategory.storageKey);
    return int.tryParse(raw ?? '') ?? PushCategory.defaultMask;
  }

  String _platform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }
}
