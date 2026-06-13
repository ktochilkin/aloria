import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:dio/dio.dart';

class MarketHttpService {
  MarketHttpService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<MarketPrice?> fetchSnapshot({
    required String symbol,
    required String exchange,
  }) async {
    try {
      final res = await _dio.getSafe<Map<String, dynamic>>(
        '/md/v2/Securities/$exchange/$symbol',
      );
      return MarketPrice.tryParse(symbol, res);
    } catch (_) {
      return null;
    }
  }

  /// Статическая деталь инструмента (без `last_price`): minStep, lotSize и т.п.
  Future<MarketPrice?> fetchInstrumentDetail({
    required String symbol,
    required String exchange,
  }) async {
    try {
      final res = await _dio.getSafe<Map<String, dynamic>>(
        '/md/v2/Securities/$exchange/$symbol',
      );
      return MarketPrice.tryParseDetail(symbol, res);
    } catch (_) {
      return null;
    }
  }

  Future<List<Candle>> fetchHistoryPrices({
    required String symbol,
    required String exchange,
    Duration lookback = const Duration(hours: 4),
    String tf = '60',
  }) async {
    final to = DateTime.now().toUtc();
    final from = to.subtract(lookback);
    final toTs = (to.millisecondsSinceEpoch / 1000).round();
    final fromTs = (from.millisecondsSinceEpoch / 1000).round();
    try {
      final raw = await _dio.getSafe<dynamic>(
        '/md/v2/history',
        queryParameters: {
          'symbol': symbol,
          'exchange': exchange,
          'from': fromTs,
          'to': toTs,
          'tf': tf,
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

  /// Создать условную (стоп) заявку: после достижения цены срабатывания
  /// выставляется рыночная или, если задана [limitPrice], лимитная заявка.
  Future<void> placeStopOrder({
    required String symbol,
    required String exchange,
    required OrderSide side,
    required StopCondition condition,
    required double triggerPrice,
    required int quantity,
    required String portfolio,
    double? limitPrice,
  }) async {
    final isLimit = limitPrice != null;
    final path = isLimit
        ? '/commandapi/warptrans/TRADE/v2/client/orders/actions/stopLimit'
        : '/commandapi/warptrans/TRADE/v2/client/orders/actions/stop';
    final reqId = 'req-${DateTime.now().microsecondsSinceEpoch}';
    await _dio.post(
      path,
      data: {
        'side': side == OrderSide.sell ? 'sell' : 'buy',
        'condition': condition.apiValue,
        'triggerPrice': triggerPrice,
        'quantity': quantity,
        if (isLimit) 'price': limitPrice,
        if (isLimit) 'timeInForce': 'oneday',
        'instrument': {'symbol': symbol, 'exchange': exchange},
        'user': {'portfolio': portfolio},
      },
      options: Options(headers: {'X-REQID': reqId}),
    );
  }

  Future<void> cancelOrder({
    required String orderId,
    required String portfolio,
    required String exchange,
    bool stop = false,
  }) async {
    await _dio.delete(
      '/commandapi/warptrans/TRADE/v2/client/orders/$orderId',
      queryParameters: {
        'portfolio': portfolio,
        'exchange': exchange,
        'stop': stop,
      },
    );
  }
}
