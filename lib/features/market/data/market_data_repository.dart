import 'dart:async';

import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/core/networking/realtime_client.dart';
import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/core/storage/storage_factory.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketDataRepository {
  MarketDataRepository({
    required Dio dio,
    required RealtimeClient realtimeClient,
    required Storage storage,
    required Ref ref,
  }) : _dio = dio,
       _realtime = realtimeClient,
       _storage = storage,
       _ref = ref;

  final Dio _dio;
  final RealtimeClient _realtime;
  final Storage _storage;
  final Ref _ref;
  static const _cachePrefix = 'quote_cache_';
  static const _maxHistory = 200;

  Future<MarketPrice?> fetchSnapshot({
    required String symbol,
    required String exchange,
  }) async {
    try {
      final res = await _dio.getSafe<Map<String, dynamic>>(
        'https://api.alor.ru/md/v2/Securities/$exchange/$symbol',
      );
      final parsed = MarketPrice.tryParse(symbol, res);
      if (parsed != null) {
        await _cachePrice(symbol, parsed);
        return parsed;
      }
    } catch (_) {
      // Fallback to cache if HTTP snapshot is unavailable.
    }
    return _loadCachedLatest(symbol);
  }

  Future<List<Candle>> fetchHistoryPrices({
    required String symbol,
    required String exchange,
    Duration lookback = const Duration(hours: 4),
    Duration tf = const Duration(minutes: 1),
  }) async {
    final to = DateTime.now().toUtc();
    final from = to.subtract(lookback);
    final toTs = (to.millisecondsSinceEpoch / 1000).round();
    final fromTs = (from.millisecondsSinceEpoch / 1000).round();
    try {
      final raw = await _dio.getSafe<dynamic>(
        'https://api.alor.ru/md/v2/history',
        queryParameters: {
          'symbol': symbol,
          'exchange': exchange,
          'from': fromTs,
          'to': toTs,
          'tf': 900,
          'format': 'Simple',
        },
      );

      final List<dynamic> rows = raw is List
          ? raw
          : raw is Map<String, dynamic>
          ? (raw['history'] as List<dynamic>? ?? const [])
          : const [];

      final candles = <Candle>[];
      for (final item in rows) {
        final map = (item as Map).cast<String, dynamic>();
        final candle = Candle.fromMap(map);
        if (!candle.isValid) continue;
        candles.add(candle);
      }
      return candles;
    } catch (_) {
      return [];
    }
  }

  Stream<MarketPrice> watchPrice({
    required String symbol,
    required String exchange,
  }) async* {
    final cached = await _loadCachedLatest(symbol);
    if (cached != null) yield cached;

    final controller = StreamController<MarketPrice>();
    StreamSubscription<Map<String, dynamic>>? sub;
    bool disposed = false;
    bool starting = false;

    Future<void> start() async {
      if (starting || disposed) return;
      starting = true;

      // Refresh token if it's close to expiring and fetch current value.
      await _ref.read(authControllerProvider.notifier).refresh(force: true);
      final token = _ref.read(authControllerProvider).tokens?.jwt;
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for realtime subscription'),
        );
        starting = false;
        return;
      }

      await _realtime.ensureConnected();
      final subId = 'quotes-$symbol-${DateTime.now().millisecondsSinceEpoch}';
      _realtime.send({
        'opcode': 'QuotesSubscribe',
        'code': symbol,
        'exchange': exchange,
        'format': 'Simple',
        'token': token,
        'guid': subId,
      });

      sub = _realtime.stream.listen(
        (event) async {
          // Reconnect on socket close sentinel.
          if (event['__ws_closed'] == true) {
            await sub?.cancel();
            sub = null;
            starting = false;
            if (!disposed) {
              Future<void>.delayed(const Duration(seconds: 1), start);
            }
            return;
          }

          final code = event['code'] as String? ?? event['symbol'] as String?;
          if (code != null && code.toUpperCase() != symbol.toUpperCase()) {
            // Some servers omit code; only filter when provided.
            return;
          }

          final price = MarketPrice.tryParse(symbol, event);
          if (price == null) return;
          await _cachePrice(symbol, price);
          if (!controller.isClosed) controller.add(price);
        },
        onError: (Object error, StackTrace stack) async {
          if (!controller.isClosed) controller.addError(error, stack);
          await sub?.cancel();
          sub = null;
          starting = false;
          if (!disposed) {
            Future<void>.delayed(const Duration(seconds: 1), start);
          }
        },
        onDone: () async {
          await sub?.cancel();
          sub = null;
          starting = false;
          if (!disposed) {
            Future<void>.delayed(const Duration(seconds: 1), start);
          }
        },
      );

      controller.onCancel = () async {
        disposed = true;
        _realtime.send({'opcode': 'Unsubscribe', 'guid': subId});
        await sub?.cancel();
        sub = null;
        if (!controller.isClosed) await controller.close();
      };

      starting = false;
    }

    await start();
    yield* controller.stream;
  }

  Stream<OrderBook> watchOrderBook({
    required String symbol,
    required String exchange,
    String? instrumentGroup,
    int depth = 10,
    int frequencyMs = 250,
  }) async* {
    final controller = StreamController<OrderBook>();
    StreamSubscription<Map<String, dynamic>>? sub;
    final subId = 'orderbook-$symbol-${DateTime.now().millisecondsSinceEpoch}';
    bool disposed = false;
    bool starting = false;

    Future<void> start() async {
      if (starting || disposed) return;
      starting = true;

      await _ref.read(authControllerProvider.notifier).refresh(force: true);
      final token = _ref.read(authControllerProvider).tokens?.jwt;
      if (token == null) {
        controller.addError(
          StateError('Auth token missing for order book subscription'),
        );
        starting = false;
        return;
      }

      await _realtime.ensureConnected();
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
      _realtime.send(payload);

      sub?.cancel();
      sub = _realtime.stream.listen(
        (event) async {
          if (event['__ws_closed'] == true) {
            await sub?.cancel();
            sub = null;
            starting = false;
            if (!disposed) {
              Future<void>.delayed(const Duration(milliseconds: 600), start);
            }
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
          await sub?.cancel();
          sub = null;
          starting = false;
          if (!disposed) {
            Future<void>.delayed(const Duration(milliseconds: 600), start);
          }
        },
        onDone: () async {
          await sub?.cancel();
          sub = null;
          starting = false;
          if (!disposed) {
            Future<void>.delayed(const Duration(milliseconds: 600), start);
          }
        },
      );

      controller.onCancel = () async {
        disposed = true;
        _realtime.send({'opcode': 'Unsubscribe', 'guid': subId});
        await sub?.cancel();
        sub = null;
        if (!controller.isClosed) await controller.close();
      };

      starting = false;
    }

    await start();
    yield* controller.stream;
  }

  Future<List<MarketPrice>> loadCachedHistory(String symbol) async {
    final raw = await _storage.read('$_cachePrefix$symbol');
    if (raw == null) return [];
    try {
      return MarketPrice.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> placeOrder(TradeOrder order) async {
    final path = order.type == OrderType.market
        ? '/commandapi/warptrans/Trade/v2/client/orders/actions/market'
        : '/commandapi/warptrans/Trade/v2/client/orders/actions/limit';
    final reqId = 'req-${DateTime.now().microsecondsSinceEpoch}';
    await _dio.post(
      path,
      data: order.toJson(),
      options: Options(headers: {'X-REQID': reqId}),
    );
  }

  Stream<List<Position>> watchPositions({
    String portfolio = TradeOrder.defaultPortfolio,
  }) async* {
    await _ref.read(authControllerProvider.notifier).refresh(force: true);
    final token = _ref.read(authControllerProvider).tokens?.jwt;
    if (token == null) {
      throw StateError('Auth token missing for positions subscription');
    }
    await _realtime.ensureConnected();
    final subId =
        'positions-$portfolio-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'opcode': 'PositionsGetAndSubscribeV2',
      'token': token,
      'guid': subId,
      'portfolio': portfolio,
      'exchange': 'MOEX',
      'format': 'Simple',
      'skipHistory': false,
    };
    _realtime.send(payload);

    final controller = StreamController<List<Position>>();
    final latest = <String, Position>{};
    late final StreamSubscription<Map<String, dynamic>> sub;

    Future<void> resubscribe() async {
      await _ref.read(authControllerProvider.notifier).refresh(force: true);
      final nextToken = _ref.read(authControllerProvider).tokens?.jwt;
      if (nextToken == null) return;
      payload['token'] = nextToken;
      await _realtime.ensureConnected();
      _realtime.send(payload);
    }

    void emitPosition(Position p) {
      if (p.symbol.isEmpty) return;
      final key = '${p.exchange}:${p.symbol}'.toUpperCase();
      latest[key] = p;
      if (!controller.isClosed) controller.add(latest.values.toList());
    }

    sub = _realtime.stream.listen(
      (event) {
        if (event['__ws_closed'] == true) {
          unawaited(resubscribe());
          return;
        }
        final guid = event['guid'] as String?;
        if (guid != null && guid != subId) return;

        final positionsRaw = event['positions'] ?? event['data'];
        if (positionsRaw is List) {
          for (final e in positionsRaw.whereType<Map<String, dynamic>>()) {
            emitPosition(Position.fromMap(e));
          }
        } else if (positionsRaw is Map) {
          emitPosition(Position.fromMap(positionsRaw.cast<String, dynamic>()));
        }
      },
      onError: controller.addError,
      onDone: () async {
        if (!controller.isClosed) await controller.close();
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      _realtime.send({'opcode': 'Unsubscribe', 'guid': subId});
      if (!controller.isClosed) await controller.close();
    };

    yield* controller.stream;
  }

  Stream<PortfolioSummary> watchPortfolioSummary({
    String portfolio = TradeOrder.defaultPortfolio,
  }) async* {
    final controller = StreamController<PortfolioSummary>();
    final latestGuid =
        'summary-$portfolio-${DateTime.now().millisecondsSinceEpoch}';

    await _ref.read(authControllerProvider.notifier).refresh(force: true);
    final token = _ref.read(authControllerProvider).tokens?.jwt;
    if (token == null) {
      throw StateError('Auth token missing for summary subscription');
    }

    await _realtime.ensureConnected();
    final payload = {
      'opcode': 'SummariesGetAndSubscribeV2',
      'token': token,
      'guid': latestGuid,
      'portfolio': portfolio,
      'exchange': 'MOEX',
      'format': 'Simple',
      'skipHistory': false,
    };
    _realtime.send(payload);

    late final StreamSubscription<Map<String, dynamic>> sub;
    Future<void> resubscribe() async {
      await _ref.read(authControllerProvider.notifier).refresh(force: true);
      final nextToken = _ref.read(authControllerProvider).tokens?.jwt;
      if (nextToken == null) return;
      payload['token'] = nextToken;
      await _realtime.ensureConnected();
      _realtime.send(payload);
    }

    sub = _realtime.stream.listen(
      (event) {
        if (event['__ws_closed'] == true) {
          unawaited(resubscribe());
          return;
        }
        final guid = event['guid'] as String?;
        if (guid != null && guid != latestGuid) return;

        final data = event['data'];
        if (data is Map<String, dynamic>) {
          final summary = PortfolioSummary.tryParse(data);
          if (summary != null && !controller.isClosed) {
            controller.add(summary);
          }
        }
      },
      onError: controller.addError,
      onDone: () async {
        if (!controller.isClosed) await controller.close();
      },
    );

    controller.onCancel = () async {
      await sub.cancel();
      _realtime.send({'opcode': 'Unsubscribe', 'guid': latestGuid});
      if (!controller.isClosed) await controller.close();
    };

    yield* controller.stream;
  }

  Future<void> _cachePrice(String symbol, MarketPrice price) async {
    final history = await loadCachedHistory(symbol);
    final updated = [...history, price];
    final trimmed = updated.length > _maxHistory
        ? updated.sublist(updated.length - _maxHistory)
        : updated;
    await _storage.write(
      '$_cachePrefix$symbol',
      MarketPrice.listToJson(trimmed),
    );
  }

  Future<MarketPrice?> _loadCachedLatest(String symbol) async {
    final history = await loadCachedHistory(symbol);
    return history.isEmpty ? null : history.last;
  }
}

final marketDataRepositoryProvider = FutureProvider<MarketDataRepository>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final storage = await ref.watch(storageProvider.future);
  final realtime = ref.watch(realtimeClientProvider);
  return MarketDataRepository(
    dio: dio,
    realtimeClient: realtime,
    storage: storage,
    ref: ref,
  );
});
