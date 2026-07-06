/// Абстракция push-канала на клиенте.
///
/// За этим интерфейсом — конкретный транспорт (FCM; реализация добавится, когда
/// в проект попадут Firebase-конфиги). Остальной код приложения (контроллер,
/// регистрация токена, deep-link по тапу) зависит только от интерфейса, поэтому
/// транспорт можно сменить, не трогая UI и логику.
abstract class PushService {
  /// Инициализация канала (подписки на сообщения/обновление токена).
  Future<void> init();

  /// Запрос разрешения на уведомления. true — разрешено.
  Future<bool> requestPermission();

  /// Текущее состояние системного разрешения — без показа диалога.
  Future<PushPermission> permissionStatus();

  /// Текущий push-токен устройства (или null, если недоступен/нет разрешения).
  Future<String?> currentToken();

  /// Обновления токена (ротация) — нужно перерегистрировать на бэке.
  Stream<String> get onTokenRefresh;

  /// Тап по уведомлению — для перехода на нужный экран (deep-link).
  Stream<PushTap> get onMessageTap;
}

/// Состояние системного разрешения на уведомления.
enum PushPermission {
  /// Разрешены (в т.ч. provisional на iOS).
  granted,

  /// Запрещены в системных настройках.
  denied,

  /// Диалог разрешения ещё не показывался.
  notDetermined,
}

/// Данные тапа по пушу: целевой маршрут для go_router + сырой payload.
class PushTap {
  const PushTap({required this.route, this.data = const {}});

  /// Маршрут для deep-link (например `/learn`, `/progress`). Приходит в `data.route`.
  final String route;
  final Map<String, String> data;

  factory PushTap.fromData(Map<String, String> data) =>
      PushTap(route: data['route'] ?? '/learn', data: data);
}
