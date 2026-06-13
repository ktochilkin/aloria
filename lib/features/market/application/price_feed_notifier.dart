import 'dart:async';

import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/candle.dart';
import 'package:aloria/features/market/domain/market_price.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Таймфрейм графика. [code] — значение Alor `tf` (в секундах) для истории
/// (REST `/md/v2/history`) и потока `BarsGetAndSubscribe`; [label] — подпись
/// для UI; [lookback] — глубина истории, чтобы набрать достаточно баров.
class ChartTimeframe {
  const ChartTimeframe(this.code, this.label, this.lookback);

  final String code;
  final String label;
  final Duration lookback;
}

/// Поддерживаемые таймфреймы графика (по возрастанию).
const kChartTimeframes = <ChartTimeframe>[
  ChartTimeframe('60', '1м', Duration(hours: 6)),
  ChartTimeframe('300', '5м', Duration(days: 1)),
  ChartTimeframe('900', '15м', Duration(days: 3)),
  ChartTimeframe('3600', '1ч', Duration(days: 14)),
  ChartTimeframe('86400', '1д', Duration(days: 180)),
];

/// Таймфрейм по умолчанию (1 минута).
const kDefaultTimeframeCode = '60';

ChartTimeframe timeframeByCode(String code) => kChartTimeframes.firstWhere(
  (t) => t.code == code,
  orElse: () => kChartTimeframes.first,
);

/// Выбранный таймфрейм графика по символу. Переживает уход со страницы, чтобы
/// при возврате на инструмент остался прежний масштаб.
final chartTimeframeProvider = StateProvider.family<String, String>((
  ref,
  symbol,
) {
  ref.keepAlive();
  return kDefaultTimeframeCode;
});

class PriceFeedState {
  final MarketPrice? latest;
  final List<MarketPrice> history;
  final List<Candle> candles;
  final bool fromCache;

  /// Текущий таймфрейм графика (код Alor `tf`).
  final String timeframe;

  /// true — идёт перезагрузка свечей под новый таймфрейм (остальной экран жив).
  final bool candlesLoading;

  const PriceFeedState({
    required this.latest,
    required this.history,
    required this.candles,
    required this.fromCache,
    this.timeframe = kDefaultTimeframeCode,
    this.candlesLoading = false,
  });

  PriceFeedState copyWith({
    MarketPrice? latest,
    List<MarketPrice>? history,
    List<Candle>? candles,
    bool? fromCache,
    String? timeframe,
    bool? candlesLoading,
  }) {
    return PriceFeedState(
      latest: latest ?? this.latest,
      history: history ?? this.history,
      candles: candles ?? this.candles,
      fromCache: fromCache ?? this.fromCache,
      timeframe: timeframe ?? this.timeframe,
      candlesLoading: candlesLoading ?? this.candlesLoading,
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

    final trimmed = updated.length > _PriceFeedNotifierLimits.maxCandles
        ? updated.sublist(updated.length - _PriceFeedNotifierLimits.maxCandles)
        : updated;

    return copyWith(candles: trimmed);
  }
}

class _PriceFeedNotifierLimits {
  /// Буфер потока свечей; график показывает последние 20.
  static const int maxCandles = 40;
}

typedef PriceFeedParams = ({String symbol, String exchange});

class PriceFeedNotifier
    extends AutoDisposeFamilyAsyncNotifier<PriceFeedState, PriceFeedParams> {
  StreamSubscription<MarketPrice>? _priceSubscription;
  StreamSubscription<Candle>? _candleSubscription;
  Timer? _keepAliveTimer;

  /// Текущий таймфрейм графика.
  String _timeframe = kDefaultTimeframeCode;

  /// Метка «поколения» подписки на свечи: переключение таймфрейма увеличивает
  /// её, и все асинхронные результаты прошлого таймфрейма отбрасываются.
  int _candleEpoch = 0;

  /// true после онуления провайдера — гард от записи в [state] после dispose.
  bool _disposed = false;

  @override
  FutureOr<PriceFeedState> build(PriceFeedParams params) async {
    _disposed = false;

    final link = ref.keepAlive();
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(const Duration(seconds: 60), link.close);

    // Текущий таймфрейм — из общего провайдера (переживает уход со страницы).
    _timeframe = ref.read(chartTimeframeProvider(params.symbol));
    // Смена таймфрейма из UI: точечно переключаем только свечи, не трогая
    // цену, стакан и общий статус экрана (без вспышки загрузки).
    ref.listen(chartTimeframeProvider(params.symbol), (_, next) {
      _applyTimeframe(next);
    });

    // Экран показывается уже после кэша (ниже), поэтому таймфрейм можно
    // переключить ещё до конца build. Если это случилось — отдаём управление
    // свечами _applyTimeframe и не подписываемся/не перетираем их здесь.
    final buildEpoch = _candleEpoch;
    bool ownsCandles() => !_disposed && _candleEpoch == buildEpoch;

    final repo = await ref.watch(marketDataRepositoryProvider.future);
    final tf = timeframeByCode(_timeframe);

    // Кэшированная история инструмента — мгновенная отрисовка.
    final cachedHistory = await repo.loadCachedHistory(params.symbol);
    var current = PriceFeedState(
      latest: cachedHistory.isNotEmpty ? cachedHistory.last : null,
      history: cachedHistory,
      candles: const [],
      fromCache: cachedHistory.isNotEmpty,
      timeframe: _timeframe,
    );
    state = AsyncData(current);

    final history = await repo.fetchHistoryPrices(
      symbol: params.symbol,
      exchange: params.exchange,
      tf: _timeframe,
      lookback: tf.lookback,
    );
    if (history.isNotEmpty) {
      // Фильтруем только данные текущего инструмента перед merge.
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

      current = current.copyWith(
        history: merged,
        // Свечи трогаем, только если их не перехватил переключатель таймфрейма.
        candles: ownsCandles() ? _trimCandles(history) : current.candles,
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
          if (_disposed || price.instrumentId != params.symbol) return;
          final next = (state.value ?? current).append(price);
          state = AsyncData(next);
        });

    // Если за время build таймфрейм переключили — свечами уже занимается
    // _applyTimeframe: не плодим вторую подписку и не перетираем его состояние.
    if (ownsCandles()) {
      _subscribeCandles(params, repo, current.candles, buildEpoch);
    }

    ref.onDispose(() async {
      _disposed = true;
      _keepAliveTimer?.cancel();
      await _priceSubscription?.cancel();
      await _candleSubscription?.cancel();
    });

    return ownsCandles() ? current : (state.value ?? current);
  }

  /// Подписка на живые свечи текущего таймфрейма. [epoch] фиксируется в
  /// замыкании — события «старого» таймфрейма игнорируются.
  void _subscribeCandles(
    PriceFeedParams params,
    MarketDataRepository repo,
    List<Candle> seed,
    int epoch,
  ) {
    final fromTime = seed.isNotEmpty
        ? seed.last.ts
        : DateTime.now().subtract(timeframeByCode(_timeframe).lookback);
    // Защита от перезаписи: всегда снимаем прежнюю подписку перед новой,
    // чтобы ни при каких гонках не осталось «висящего» слушателя свечей.
    _candleSubscription?.cancel();
    _candleSubscription = repo
        .watchCandles(
          symbol: params.symbol,
          exchange: params.exchange,
          timeframe: _timeframe,
          fromTime: fromTime,
        )
        .listen((candle) {
          if (_disposed || epoch != _candleEpoch) return;
          final c = state.value;
          if (c == null) return;
          state = AsyncData(c.updateCandle(candle));
        });
  }

  /// Переключение таймфрейма графика. Снимает старую подписку на свечи,
  /// подгружает историю под новый масштаб и подписывается заново — цена и
  /// стакан остаются на месте, общий статус экрана не сбрасывается в загрузку.
  Future<void> _applyTimeframe(String code) async {
    if (_disposed || code == _timeframe) return;
    _timeframe = code;
    final epoch = ++_candleEpoch;

    await _candleSubscription?.cancel();
    _candleSubscription = null;
    if (_disposed || epoch != _candleEpoch) return;

    // Показываем загрузку только на графике, не трогая остальное состояние.
    final base = state.value;
    if (base != null) {
      state = AsyncData(
        base.copyWith(timeframe: code, candles: const [], candlesLoading: true),
      );
    }

    final params = arg;
    final repo = await ref.read(marketDataRepositoryProvider.future);
    if (_disposed || epoch != _candleEpoch) return;

    final bars = await repo.fetchHistoryPrices(
      symbol: params.symbol,
      exchange: params.exchange,
      tf: code,
      lookback: timeframeByCode(code).lookback,
    );
    if (_disposed || epoch != _candleEpoch) return;

    final trimmed = _trimCandles(bars);
    final cur = state.value;
    if (cur != null) {
      state = AsyncData(cur.copyWith(candles: trimmed, candlesLoading: false));
    }

    _subscribeCandles(params, repo, trimmed, epoch);
  }

  List<Candle> _trimCandles(List<Candle> bars) {
    final valid = bars.where((c) => c.isValid).toList();
    const max = _PriceFeedNotifierLimits.maxCandles;
    return valid.length > max ? valid.sublist(valid.length - max) : valid;
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

/// Разовая деталь инструмента из REST `/md/v2/Securities/{exchange}/{symbol}`:
/// несёт статику, которой нет в потоке котировок (минимальный шаг цены и т.п.).
final instrumentDetailProvider = FutureProvider.autoDispose
    .family<MarketPrice?, PriceFeedParams>((ref, params) async {
      final repo = await ref.watch(marketDataRepositoryProvider.future);
      return repo.fetchInstrumentDetail(
        symbol: params.symbol,
        exchange: params.exchange,
      );
    });
