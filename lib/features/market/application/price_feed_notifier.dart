import 'dart:async';

import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PriceFeedState {
  final MarketPrice? latest;
  final List<MarketPrice> history;
  final List<Candle> candles;
  final bool fromCache;

  const PriceFeedState({
    required this.latest,
    required this.history,
    required this.candles,
    required this.fromCache,
  });

  PriceFeedState copyWith({
    MarketPrice? latest,
    List<MarketPrice>? history,
    List<Candle>? candles,
    bool? fromCache,
  }) {
    return PriceFeedState(
      latest: latest ?? this.latest,
      history: history ?? this.history,
      candles: candles ?? this.candles,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  PriceFeedState append(MarketPrice price) {
    final updatedHistory = [...history, price];
    const maxHistory = 200;
    final trimmed = updatedHistory.length > maxHistory
        ? updatedHistory.sublist(updatedHistory.length - maxHistory)
        : updatedHistory;
    return copyWith(latest: price, history: trimmed, fromCache: false);
  }
}

typedef PriceFeedParams = ({String symbol, String exchange});

class PriceFeedNotifier
    extends AutoDisposeFamilyAsyncNotifier<PriceFeedState, PriceFeedParams> {
  StreamSubscription<MarketPrice>? _subscription;
  Timer? _keepAliveTimer;

  @override
  FutureOr<PriceFeedState> build(PriceFeedParams params) async {
    // Сохраняем провайдер активным для сохранения состояния
    final link = ref.keepAlive();

    // Автоматически очищаем через 60 секунд неактивности
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(const Duration(seconds: 60), link.close);

    final repo = await ref.watch(marketDataRepositoryProvider.future);
    final cachedHistory = await repo.loadCachedHistory(params.symbol);
    var current = PriceFeedState(
      latest: cachedHistory.isNotEmpty ? cachedHistory.last : null,
      history: cachedHistory,
      candles: const [],
      fromCache: cachedHistory.isNotEmpty,
    );
    state = AsyncData(current);

    final history = await repo.fetchHistoryPrices(
      symbol: params.symbol,
      exchange: params.exchange,
    );
    if (history.isNotEmpty) {
      final merged = _mergeHistory(
        current.history,
        history
            .where((c) => c.isValid)
            .map(
              (c) => MarketPrice(
                instrumentId: params.symbol,
                price: c.close,
                ts: c.ts,
              ),
            )
            .toList(),
      );
      current = current.copyWith(
        history: merged,
        candles: history,
        latest: merged.isNotEmpty ? merged.last : current.latest,
        fromCache: false,
      );
      state = AsyncData(current);
    }

    final snapshot = await repo.fetchSnapshot(
      symbol: params.symbol,
      exchange: params.exchange,
    );
    if (snapshot != null) {
      current = current.append(snapshot);
      state = AsyncData(current);
    }

    _subscription = repo
        .watchPrice(symbol: params.symbol, exchange: params.exchange)
        .listen((price) {
          final next = (state.value ?? current).append(price);
          state = AsyncData(next);
        });

    ref.onDispose(() async {
      _keepAliveTimer?.cancel();
      await _subscription?.cancel();
    });

    return current;
  }
}

List<MarketPrice> _mergeHistory(List<MarketPrice> a, List<MarketPrice> b) {
  final byTs = <int, MarketPrice>{};
  for (final p in [...a, ...b]) {
    byTs[p.ts.millisecondsSinceEpoch] = p;
  }
  final merged = byTs.values.toList()..sort((l, r) => l.ts.compareTo(r.ts));
  const maxHistory = 200;
  return merged.length > maxHistory
      ? merged.sublist(merged.length - maxHistory)
      : merged;
}

final priceFeedProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      PriceFeedNotifier,
      PriceFeedState,
      PriceFeedParams
    >(PriceFeedNotifier.new);
