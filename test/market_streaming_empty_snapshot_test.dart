import 'dart:async';

import 'package:aloria/core/networking/realtime_client.dart';
import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/features/market/data/market_cache.dart';
import 'package:aloria/features/market/data/market_http_service.dart';
import 'package:aloria/features/market/data/market_streaming_service.dart';
import 'package:aloria/features/market/data/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Регрессия: при пустом снапшоте (заявки/сделки система обнуляет каждый
/// торговый день) поток `*GetAndSubscribeV2` обязан эмитить пустой список по
/// подтверждению подписки (ServiceMessage200), иначе провайдер навсегда
/// зависает в состоянии загрузки — вкладка крутит бесконечное колесо.
void main() {
  late _FakeRealtime portfolio;
  late MarketStreamingService service;

  setUp(() {
    portfolio = _FakeRealtime();
    service = MarketStreamingService(
      tradingRealtime: _FakeRealtime(),
      portfolioRealtime: portfolio,
      tokenProvider: _FakeToken(),
      cache: MarketCache(storage: _FakeStorage()),
      http: MarketHttpService(dio: Dio()),
    );
  });

  test('пустой снапшот заявок → поток эмитит пустой список по ack', () async {
    final emissions = <List<dynamic>>[];
    final sub = service.watchOrders().listen(emissions.add);

    // Ждём, пока подписка отправит запрос, и фейк ответит только
    // подтверждением (без единой заявки) — как для обнулённого портфеля.
    await portfolio.ackLastSubscription();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emissions, isNotEmpty,
        reason: 'поток должен эмитить хотя бы пустой список');
    expect(emissions.last, isEmpty);
    await sub.cancel();
  });

  test('сначала ack, затем живая заявка → список наполняется', () async {
    final emissions = <List<dynamic>>[];
    final sub = service.watchOrders().listen(emissions.add);

    await portfolio.ackLastSubscription();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(emissions.last, isEmpty);

    portfolio.push({
      'guid': portfolio.lastGuid,
      'data': {
        'id': '777',
        'symbol': 'SBER',
        'portfolio': 'T00013',
        'exchange': 'TEREX',
        'type': 'limit',
        'side': 'buy',
        'status': 'working',
        'qty': 1,
        'price': 100.0,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emissions.last, hasLength(1));
    await sub.cancel();
  });

  test('пустой снапшот сделок → поток эмитит пустой список по ack', () async {
    final emissions = <List<dynamic>>[];
    final sub = service.watchTrades().listen(emissions.add);

    await portfolio.ackLastSubscription();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emissions, isNotEmpty);
    expect(emissions.last, isEmpty);
    await sub.cancel();
  });

  test('ack чужой подписки не эмитит пустой список', () async {
    final emissions = <List<dynamic>>[];
    final sub = service.watchOrders().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Подтверждение с requestGuid другой подписки не должно завершать загрузку.
    portfolio.push({
      'requestGuid': 'someone-else',
      'httpCode': 200,
      'message': 'Handled successfully',
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emissions, isEmpty);
    await sub.cancel();
  });

  test('401 от подписки → поток отдаёт ошибку, а не вечную загрузку', () async {
    Object? caughtError;
    final sub = service.watchOrders().listen(
      (_) {},
      onError: (Object e) => caughtError = e,
    );
    await portfolio.waitForSubscription();
    portfolio.push({
      'requestGuid': portfolio.lastGuid,
      'httpCode': 401,
      'message': 'Invalid JWT token!',
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(caughtError, isNotNull);
    await sub.cancel();
  });

  test('после reconnect устаревшая заявка не воскресает', () async {
    final emissions = <List<dynamic>>[];
    final sub = service.watchOrders().listen(emissions.add);

    await portfolio.ackLastSubscription();
    portfolio.push({
      'guid': portfolio.lastGuid,
      'data': {
        'id': '555',
        'symbol': 'GAZP',
        'portfolio': 'T00013',
        'exchange': 'TEREX',
        'type': 'limit',
        'side': 'buy',
        'status': 'working',
        'qty': 3,
        'price': 120.0,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(emissions.last, hasLength(1));

    // Обрыв соединения → переподписка (_handleReconnect, задержка 1000мс).
    portfolio.push({'__ws_closed': true});
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // Новый снапшот пуст (заявка снята/исполнена за время обрыва).
    await portfolio.ackLastSubscription();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emissions.last, isEmpty,
        reason: 'старая заявка не должна пережить переподключение');
    await sub.cancel();
  });
}

/// Фейковый realtime-клиент: запоминает guid последней подписки и умеет
/// ответить подтверждением (ServiceMessage200) или произвольным событием.
class _FakeRealtime implements RealtimeClient {
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _sent = <Map<String, dynamic>>[];

  String? get lastGuid => _sent.isEmpty ? null : _sent.last['guid'] as String?;

  @override
  Future<void> ensureConnected() async {}

  @override
  Stream<Map<String, dynamic>> get stream => _controller.stream;

  @override
  void send(Map<String, dynamic> message) => _sent.add(message);

  void push(Map<String, dynamic> event) => _controller.add(event);

  /// Дожидается, пока сервис отправит хотя бы один запрос подписки.
  Future<void> waitForSubscription() async {
    for (var i = 0; i < 80 && _sent.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Дожидается отправки подписки и отвечает только подтверждением.
  Future<void> ackLastSubscription() async {
    await waitForSubscription();
    push({
      'requestGuid': lastGuid,
      'httpCode': 200,
      'message': 'Handled successfully',
    });
  }

  @override
  Future<void> close() => _controller.close();
}

class _FakeToken implements TokenProvider {
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'jwt';
}

class _FakeStorage implements Storage {
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> clear() async {}
}
