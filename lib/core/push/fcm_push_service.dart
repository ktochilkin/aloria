import 'dart:async';

import 'package:aloria/core/push/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Реализация [PushService] поверх Firebase Cloud Messaging.
///
/// Уведомления с блоком notification iOS показывает сам (в фоне/закрытом
/// состоянии), а в форграунде — через [setForegroundNotificationPresentationOptions].
/// Тап по уведомлению (из фона и из закрытого состояния) превращается в [PushTap].
class FcmPushService implements PushService {
  FcmPushService() : _msg = FirebaseMessaging.instance;

  final FirebaseMessaging _msg;
  final _tapController = StreamController<PushTap>.broadcast();

  @override
  Future<void> init() async {
    await _msg.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Тап по пушу, когда приложение в фоне.
    FirebaseMessaging.onMessageOpenedApp.listen(_emitTap);

    // Тап, поднявший приложение из закрытого состояния.
    final initial = await _msg.getInitialMessage();
    if (initial != null) _emitTap(initial);
  }

  void _emitTap(RemoteMessage message) {
    if (_tapController.isClosed) return;
    final data = message.data.map((k, v) => MapEntry(k, '$v'));
    _tapController.add(PushTap.fromData(data));
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _msg.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> currentToken() => _msg.getToken();

  @override
  Stream<String> get onTokenRefresh => _msg.onTokenRefresh;

  @override
  Stream<PushTap> get onMessageTap => _tapController.stream;

  void dispose() {
    _tapController.close();
  }
}
