import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/core/networking/realtime_client.dart';
import 'package:aloria/core/storage/storage_factory.dart';
import 'package:aloria/features/market/data/market_cache.dart';
import 'package:aloria/features/market/data/market_http_service.dart';
import 'package:aloria/features/market/data/market_streaming_service.dart';
import 'package:aloria/features/market/data/token_provider.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:aloria/features/market/domain/trade_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketDataRepository {
  MarketDataRepository({
    required MarketHttpService http,
    required MarketStreamingService streaming,
    required MarketCache cache,
  }) : _http = http,
       _streaming = streaming,
       _cache = cache;

  final MarketHttpService _http;
  final MarketStreamingService _streaming;
  final MarketCache _cache;

  Future<MarketPrice?> fetchSnapshot({
    required String symbol,
    required String exchange,
  }) async {
    final snapshot = await _http.fetchSnapshot(
      symbol: symbol,
      exchange: exchange,
    );
    if (snapshot != null) {
      await _cache.appendPrice(symbol, snapshot);
      return snapshot;
    }
    final history = await _cache.loadHistory(symbol);
    return history.isEmpty ? null : history.last;
  }

  Future<List<Candle>> fetchHistoryPrices({
    required String symbol,
    required String exchange,
    Duration lookback = const Duration(hours: 4),
    Duration tf = const Duration(minutes: 1),
  }) {
    return _http.fetchHistoryPrices(
      symbol: symbol,
      exchange: exchange,
      lookback: lookback,
      tf: tf,
    );
  }

  Stream<MarketPrice> watchPrice({
    required String symbol,
    required String exchange,
  }) => _streaming.watchPrice(symbol: symbol, exchange: exchange);

  Stream<OrderBook> watchOrderBook({
    required String symbol,
    required String exchange,
    String? instrumentGroup,
    int depth = 10,
    int frequencyMs = 250,
  }) => _streaming.watchOrderBook(
    symbol: symbol,
    exchange: exchange,
    instrumentGroup: instrumentGroup,
    depth: depth,
    frequencyMs: frequencyMs,
  );

  Future<List<MarketPrice>> loadCachedHistory(String symbol) =>
      _cache.loadHistory(symbol);

  Future<void> placeOrder(TradeOrder order) => _http.placeOrder(order);

  Future<void> cancelOrder({
    required String orderId,
    required String portfolio,
    required String exchange,
    bool stop = false,
  }) => _http.cancelOrder(
    orderId: orderId,
    portfolio: portfolio,
    exchange: exchange,
    stop: stop,
  );

  Stream<List<Position>> watchPositions({
    String portfolio = TradeOrder.defaultPortfolio,
  }) => _streaming.watchPositions(portfolio: portfolio);

  Stream<PortfolioSummary> watchPortfolioSummary({
    String portfolio = TradeOrder.defaultPortfolio,
  }) => _streaming.watchPortfolioSummary(portfolio: portfolio);

  Stream<List<ClientOrder>> watchOrders({
    String portfolio = TradeOrder.defaultPortfolio,
  }) => _streaming.watchOrders(portfolio: portfolio);
}

final marketDataRepositoryProvider = FutureProvider<MarketDataRepository>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  final storage = await ref.watch(storageProvider.future);
  final tradingRealtime = ref.watch(tradingRealtimeClientProvider);
  final portfolioRealtime = ref.watch(portfolioRealtimeClientProvider);
  final tokenProvider = RiverpodTokenProvider(ref);
  final cache = MarketCache(storage: storage);
  final http = MarketHttpService(dio: dio);
  final streaming = MarketStreamingService(
    tradingRealtime: tradingRealtime,
    portfolioRealtime: portfolioRealtime,
    tokenProvider: tokenProvider,
    cache: cache,
    http: http,
  );
  return MarketDataRepository(http: http, streaming: streaming, cache: cache);
});
