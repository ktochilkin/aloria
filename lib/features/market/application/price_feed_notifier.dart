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

  PriceFeedState updateCandle(Candle newCandle) {
    if (candles.isEmpty) {
      // Добавляем первую свечу и ограничиваем до 10
      return copyWith(candles: [newCandle]);
    }

    final lastCandle = candles.last;
    final isSameCandle =
        lastCandle.ts.millisecondsSinceEpoch ==
        newCandle.ts.millisecondsSinceEpoch;

    List<Candle> updated;
    if (isSameCandle) {
      // Обновляем последнюю свечу
      updated = [...candles.sublist(0, candles.length - 1), newCandle];
    } else {
      // Добавляем новую свечу
      updated = [...candles, newCandle];
    }

    // Ограничиваем до 10 последних свечей
    const maxCandles = 10;
    final trimmed = updated.length > maxCandles
        ? updated.sublist(updated.length - maxCandles)
        : updated;

    return copyWith(candles: trimmed);
  }
}

typedef PriceFeedParams = ({String symbol, String exchange});

class PriceFeedNotifier
    extends AutoDisposeFamilyAsyncNotifier<PriceFeedState, PriceFeedParams> {
  StreamSubscription<MarketPrice>? _priceSubscription;
  StreamSubscription<Candle>? _candleSubscription;
  Timer? _keepAliveTimer;

  @override
  FutureOr<PriceFeedState> build(PriceFeedParams params) async {
    // Сохраняем провайдер активным для сохранения состояния
    final link = ref.keepAlive();

    // Автоматически очищаем через 60 секунд неактивности
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(const Duration(seconds: 60), link.close);

    final repo = await ref.watch(marketDataRepositoryProvider.future);

    // Загружаем кэшированную историю для данного инструмента
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
      tfMinutes: 60,
    );
    if (history.isNotEmpty) {
      // Фильтруем только данные текущего инструмента перед merge
      final filtered = current.history
          .where((p) => p.instrumentId == params.symbol)
          .toList();
      final merged = _mergeHistory(
        filtered,
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

      // Обрезаем свечи до 10 последних сразу при загрузке
      const maxCandles = 10;
      final trimmedCandles = history.length > maxCandles
          ? history.sublist(history.length - maxCandles)
          : history;

      current = current.copyWith(
        history: merged,
        candles: trimmedCandles,
        latest: merged.isNotEmpty ? merged.last : current.latest,
        fromCache: false,
      );
      state = AsyncData(current);
    }

    final snapshot = await repo.fetchSnapshot(
      symbol: params.symbol,
      exchange: params.exchange,
    );
    if (snapshot != null && snapshot.instrumentId == params.symbol) {
      current = current.append(snapshot);
      state = AsyncData(current);
    }

    _priceSubscription = repo
        .watchPrice(symbol: params.symbol, exchange: params.exchange)
        .listen((price) {
          // Проверяем что цена относится к нашему инструменту
          if (price.instrumentId != params.symbol) return;
          final next = (state.value ?? current).append(price);
          state = AsyncData(next);
        });

    // Подписываемся на обновления свечей
    // from = время самой молодой (последней) свечи, чтобы обновлять активную свечу
    final fromTime = current.candles.isNotEmpty
        ? current.candles.last.ts
        : DateTime.now().subtract(const Duration(hours: 10));

    _candleSubscription = repo
        .watchCandles(
          symbol: params.symbol,
          exchange: params.exchange,
          instrumentGroup: null,
          timeframe: '60', // 1 час
          fromTime: fromTime,
        )
        .listen((candle) {
          final next = (state.value ?? current).updateCandle(candle);
          state = AsyncData(next);
        });

    ref.onDispose(() async {
      _keepAliveTimer?.cancel();
      await _priceSubscription?.cancel();
      await _candleSubscription?.cancel();
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
