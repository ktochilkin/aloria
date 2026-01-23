import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
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
        '/md/v2/history',
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
}
