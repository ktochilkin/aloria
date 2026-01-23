import 'dart:async';

import 'package:aloria/core/networking/realtime_client.dart';
import 'package:aloria/features/market/data/market_cache.dart';
import 'package:aloria/features/market/data/market_http_service.dart';
import 'package:aloria/features/market/data/token_provider.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/trade_order.dart';

class MarketStreamingService {
  MarketStreamingService({
    required RealtimeClient tradingRealtime,
    required RealtimeClient portfolioRealtime,
    required TokenProvider tokenProvider,
    required MarketCache cache,
    required MarketHttpService http,
  }) : _tradingRealtime = tradingRealtime,
       _portfolioRealtime = portfolioRealtime,
       _tokenProvider = tokenProvider,
       _cache = cache,
       _http = http;

  final RealtimeClient _tradingRealtime;
  final RealtimeClient _portfolioRealtime;
  final TokenProvider _tokenProvider;
  final MarketCache _cache;
  final MarketHttpService _http;

  final _priceSubs = <String, _PriceSubscription>{};
  final _orderBookSubs = <String, _OrderBookSubscription>{};
  final _positionsSubs = <String, _SharedSubscription<List<Position>>>{};
  final _summarySubs = <String, _SharedSubscription<PortfolioSummary>>{};
  final _ordersSubs = <String, _SharedSubscription<List<ClientOrder>>>{};

  Stream<MarketPrice> watchPrice({
    required String symbol,
    required String exchange,
  }) async* {
    final key = 'price:$exchange:$symbol';
    final existing = _priceSubs[key];
    if (existing != null) {
      existing.listeners++;
      yield* existing.controller.stream;
      return;
    }

    final controller = StreamController<MarketPrice>.broadcast();
    final subState = _PriceSubscription(controller: controller, listeners: 1);
    _priceSubs[key] = subState;

    Future<void> subscribe() async {
      if (subState.disposed) return;
      final token = await _tokenProvider.accessToken(forceRefresh: true);
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for realtime subscription'),
        );
        return;
      }

      await _tradingRealtime.ensureConnected();
      final subId = 'quotes-$symbol-${DateTime.now().millisecondsSinceEpoch}';
      subState.subId = subId;
      _tradingRealtime.send({
        'opcode': 'QuotesSubscribe',
        'code': symbol,
        'exchange': exchange,
        'format': 'Simple',
        'token': token,
        'guid': subId,
      });

      subState.sub?.cancel();
      subState.sub = _tradingRealtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await _handleReconnect(subscribe, subState.disposed);
            return;
          }
          final code = event['code'] as String? ?? event['symbol'] as String?;
          if (code != null && code.toUpperCase() != symbol.toUpperCase()) {
            return;
          }
          final price = MarketPrice.tryParse(symbol, event);
          if (price == null) return;
          await _cache.appendPrice(symbol, price);
          if (!controller.isClosed) controller.add(price);
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await _handleReconnect(subscribe, subState.disposed);
        },
        onDone: () async {
          await _handleReconnect(subscribe, subState.disposed);
        },
      );
    }

    controller.onListen = () async {
      if (subState.started) return;
      subState.started = true;
      final cached = await _cache.loadHistory(symbol);
      if (cached.isNotEmpty && !controller.isClosed) {
        controller.add(cached.last);
      }
      final snapshot = await _http.fetchSnapshot(
        symbol: symbol,
        exchange: exchange,
      );
      if (snapshot != null && !controller.isClosed) {
        await _cache.appendPrice(symbol, snapshot);
        controller.add(snapshot);
      }
      await subscribe();
    };

    controller.onCancel = () async {
      subState.listeners = 0;
      final shouldDispose = true;
      subState.disposed = true;
      if (subState.subId != null) {
        _tradingRealtime.send({
          'opcode': 'Unsubscribe',
          'guid': subState.subId,
        });
      }
      await subState.sub?.cancel();
      subState.sub = null;
      await controller.close();
      _priceSubs.remove(key);
    };

    yield* controller.stream;
  }

  Stream<OrderBook> watchOrderBook({
    required String symbol,
    required String exchange,
    String? instrumentGroup,
    int depth = 10,
    int frequencyMs = 250,
  }) async* {
    final key =
        'orderbook:$exchange:$symbol:$instrumentGroup:$depth:$frequencyMs';
    final existing = _orderBookSubs[key];
    if (existing != null) {
      existing.listeners++;
      yield* existing.controller.stream;
      return;
    }

    final controller = StreamController<OrderBook>.broadcast();
    final subState = _OrderBookSubscription(
      controller: controller,
      listeners: 1,
    );
    _orderBookSubs[key] = subState;

    Future<void> subscribe() async {
      if (subState.disposed) return;
      final token = await _tokenProvider.accessToken(forceRefresh: true);
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for order book subscription'),
        );
        return;
      }

      await _tradingRealtime.ensureConnected();
      final subId =
          'orderbook-$symbol-${DateTime.now().millisecondsSinceEpoch}';
      subState.subId = subId;
      final payload = {
        'opcode': 'OrderBookGetAndSubscribe',
        'exchange': exchange,
        'code': symbol,
        'depth': depth,
        'format': 'Simple',
        'frequency': frequencyMs,
        'guid': subId,
        'token': token,
      };
      if (instrumentGroup != null && instrumentGroup.isNotEmpty) {
        payload['instrumentGroup'] = instrumentGroup;
      }
      _tradingRealtime.send(payload);

      subState.sub?.cancel();
      subState.sub = _tradingRealtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await _handleReconnect(subscribe, subState.disposed, delayMs: 600);
            return;
          }
          final guid = event['guid'] as String?;
          if (guid != null && guid != subId) return;
          final book = OrderBook.tryParse(event);
          if (book == null) return;
          final trimmed = book.trimmed(depth);
          if (!controller.isClosed) controller.add(trimmed);
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await _handleReconnect(subscribe, subState.disposed, delayMs: 600);
        },
        onDone: () async {
          await _handleReconnect(subscribe, subState.disposed, delayMs: 600);
        },
      );
    }

    controller.onCancel = () async {
      subState.listeners = 0;
      final shouldDispose = true;
      subState.disposed = true;
      if (subState.subId != null) {
        _tradingRealtime.send({
          'opcode': 'Unsubscribe',
          'guid': subState.subId,
        });
      }
      await subState.sub?.cancel();
      subState.sub = null;
      await controller.close();
      _orderBookSubs.remove(key);
    };

    await subscribe();
    yield* controller.stream;
  }

  Stream<List<Position>> watchPositions({
    String portfolio = TradeOrder.defaultPortfolio,
  }) async* {
    final key = 'positions:$portfolio';
    final existing = _positionsSubs[key];
    if (existing != null) {
      existing.listeners++;
      yield* existing.controller.stream;
      return;
    }

    final controller = StreamController<List<Position>>.broadcast();
    final latest = <String, Position>{};
    final subState = _SharedSubscription<List<Position>>(
      controller: controller,
      listeners: 1,
    );
    _positionsSubs[key] = subState;

    Future<void> subscribe() async {
      if (subState.disposed) return;
      final token = await _tokenProvider.accessToken(forceRefresh: true);
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for positions subscription'),
        );
        return;
      }

      await _portfolioRealtime.ensureConnected();
      final subId =
          'positions-$portfolio-${DateTime.now().millisecondsSinceEpoch}';
      subState.subId = subId;
      final payload = {
        'opcode': 'PositionsGetAndSubscribeV2',
        'token': token,
        'guid': subId,
        'portfolio': portfolio,
        'exchange': 'TEREX',
        'format': 'Simple',
        'skipHistory': false,
      };
      _portfolioRealtime.send(payload);

      subState.sub?.cancel();
      subState.sub = _portfolioRealtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await _handleReconnect(subscribe, subState.disposed);
            return;
          }
          final guid = event['guid'] as String?;
          if (guid != null && guid != subId) return;

          final positionsRaw = event['positions'] ?? event['data'];
          if (positionsRaw is List) {
            for (final e in positionsRaw.whereType<Map<String, dynamic>>()) {
              _emitPosition(e, latest, controller);
            }
          } else if (positionsRaw is Map) {
            _emitPosition(
              positionsRaw.cast<String, dynamic>(),
              latest,
              controller,
            );
          }
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await _handleReconnect(subscribe, subState.disposed);
        },
        onDone: () async {
          await _handleReconnect(subscribe, subState.disposed);
        },
      );
    }

    controller.onCancel = () async {
      subState.listeners = 0;
      final shouldDispose = true;
      subState.disposed = true;
      if (subState.subId != null) {
        _portfolioRealtime.send({
          'opcode': 'Unsubscribe',
          'guid': subState.subId,
        });
      }
      await subState.sub?.cancel();
      subState.sub = null;
      await controller.close();
      _positionsSubs.remove(key);
    };

    await subscribe();
    yield* controller.stream;
  }

  Stream<PortfolioSummary> watchPortfolioSummary({
    String portfolio = TradeOrder.defaultPortfolio,
  }) async* {
    final key = 'summary:$portfolio';
    final existing = _summarySubs[key];
    if (existing != null) {
      existing.listeners++;
      yield* existing.controller.stream;
      return;
    }

    final controller = StreamController<PortfolioSummary>.broadcast();
    final subState = _SharedSubscription<PortfolioSummary>(
      controller: controller,
      listeners: 1,
    );
    _summarySubs[key] = subState;

    Future<void> subscribe() async {
      if (subState.disposed) return;
      final token = await _tokenProvider.accessToken(forceRefresh: true);
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for summary subscription'),
        );
        return;
      }

      await _portfolioRealtime.ensureConnected();
      final subId =
          'summary-$portfolio-${DateTime.now().millisecondsSinceEpoch}';
      subState.subId = subId;
      final payload = {
        'opcode': 'SummariesGetAndSubscribeV2',
        'token': token,
        'guid': subId,
        'portfolio': portfolio,
        'exchange': 'TEREX',
        'format': 'Simple',
        'skipHistory': false,
      };
      _portfolioRealtime.send(payload);

      subState.sub?.cancel();
      subState.sub = _portfolioRealtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await _handleReconnect(subscribe, subState.disposed);
            return;
          }
          final guid = event['guid'] as String?;
          if (guid != null && guid != subId) return;
          final data = event['data'];
          if (data is Map<String, dynamic>) {
            final summary = PortfolioSummary.tryParse(data);
            if (summary != null && !controller.isClosed) {
              controller.add(summary);
            }
          }
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await _handleReconnect(subscribe, subState.disposed);
        },
        onDone: () async {
          await _handleReconnect(subscribe, subState.disposed);
        },
      );
    }

    controller.onCancel = () async {
      subState.listeners = 0;
      final shouldDispose = true;
      subState.disposed = true;
      if (subState.subId != null) {
        _portfolioRealtime.send({
          'opcode': 'Unsubscribe',
          'guid': subState.subId,
        });
      }
      await subState.sub?.cancel();
      subState.sub = null;
      await controller.close();
      _summarySubs.remove(key);
    };

    await subscribe();
    yield* controller.stream;
  }

  Stream<List<ClientOrder>> watchOrders({
    String portfolio = TradeOrder.defaultPortfolio,
  }) async* {
    final key = 'orders:$portfolio';
    final existing = _ordersSubs[key];
    if (existing != null) {
      existing.listeners++;
      yield* existing.controller.stream;
      return;
    }

    final controller = StreamController<List<ClientOrder>>.broadcast();
    final latest = <String, ClientOrder>{};
    final subState = _SharedSubscription<List<ClientOrder>>(
      controller: controller,
      listeners: 1,
    );
    _ordersSubs[key] = subState;

    Future<void> subscribe() async {
      if (subState.disposed) return;
      final token = await _tokenProvider.accessToken(forceRefresh: true);
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for orders subscription'),
        );
        return;
      }

      await _portfolioRealtime.ensureConnected();
      final subId =
          'orders-$portfolio-${DateTime.now().millisecondsSinceEpoch}';
      subState.subId = subId;
      final payload = {
        'opcode': 'OrdersGetAndSubscribeV2',
        'token': token,
        'guid': subId,
        'portfolio': portfolio,
        'exchange': 'TEREX',
        'format': 'Simple',
        'skipHistory': false,
      };
      _portfolioRealtime.send(payload);

      subState.sub?.cancel();
      subState.sub = _portfolioRealtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await _handleReconnect(subscribe, subState.disposed);
            return;
          }
          final guid = event['guid'] as String?;
          if (guid != null && guid != subId) return;

          final data = event['data'];
          if (data is List) {
            for (final e in data.whereType<Map<String, dynamic>>()) {
              _emitOrder(e, latest, controller);
            }
            return;
          }
          if (data is Map<String, dynamic>) {
            _emitOrder(data, latest, controller);
          }
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await _handleReconnect(subscribe, subState.disposed);
        },
        onDone: () async {
          await _handleReconnect(subscribe, subState.disposed);
        },
      );
    }

    controller.onCancel = () async {
      subState.listeners = 0;
      subState.disposed = true;
      if (subState.subId != null) {
        _portfolioRealtime.send({
          'opcode': 'Unsubscribe',
          'guid': subState.subId,
        });
      }
      await subState.sub?.cancel();
      subState.sub = null;
      await controller.close();
      _ordersSubs.remove(key);
    };

    await subscribe();
    yield* controller.stream;
  }

  Future<void> _handleReconnect(
    Future<void> Function() restart,
    bool disposed, {
    int delayMs = 1000,
  }) async {
    if (disposed) return;
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    await restart();
  }

  void _emitPosition(
    Map<String, dynamic> raw,
    Map<String, Position> latest,
    StreamController<List<Position>> controller,
  ) {
    final position = Position.fromMap(raw);
    if (position.symbol.isEmpty) return;
    final key = '${position.exchange}:${position.symbol}'.toUpperCase();
    latest[key] = position;
    if (!controller.isClosed) controller.add(latest.values.toList());
  }

  void _emitOrder(
    Map<String, dynamic> raw,
    Map<String, ClientOrder> latest,
    StreamController<List<ClientOrder>> controller,
  ) {
    final order = ClientOrder.fromMap(raw);
    if (order == null) return;
    latest[order.id] = order;
    final sorted = latest.values.toList()
      ..sort((a, b) {
        final activeCmp = (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0);
        if (activeCmp != 0) return activeCmp;
        final aTime = a.updateTime ?? a.transTime;
        final bTime = b.updateTime ?? b.transTime;
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        return b.id.compareTo(a.id);
      });
    if (!controller.isClosed) controller.add(sorted);
  }
}

class _PriceSubscription {
  _PriceSubscription({required this.controller, required this.listeners});

  final StreamController<MarketPrice> controller;
  int listeners;
  StreamSubscription<Map<String, dynamic>>? sub;
  String? subId;
  bool disposed = false;
  bool started = false;
}

class _OrderBookSubscription {
  _OrderBookSubscription({required this.controller, required this.listeners});

  final StreamController<OrderBook> controller;
  int listeners;
  StreamSubscription<Map<String, dynamic>>? sub;
  String? subId;
  bool disposed = false;
}

class _SharedSubscription<T> {
  _SharedSubscription({required this.controller, required this.listeners});

  final StreamController<T> controller;
  int listeners;
  StreamSubscription<Map<String, dynamic>>? sub;
  String? subId;
  bool disposed = false;
}
