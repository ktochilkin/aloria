import 'dart:async';

import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/order_book.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OrderBookParams = ({
  String symbol,
  String exchange,
  String? instrumentGroup,
  int depth,
});

class OrderBookNotifier
    extends AutoDisposeFamilyAsyncNotifier<OrderBook?, OrderBookParams> {
  StreamSubscription<OrderBook>? _subscription;
  Timer? _keepAliveTimer;

  @override
  FutureOr<OrderBook?> build(OrderBookParams params) async {
    // Сохраняем провайдер активным для сохранения состояния
    final link = ref.keepAlive();

    // Автоматически очищаем через 60 секунд неактивности
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(const Duration(seconds: 60), link.close);

    final repo = await ref.watch(marketDataRepositoryProvider.future);
    _subscription = repo
        .watchOrderBook(
          symbol: params.symbol,
          exchange: params.exchange,
          instrumentGroup: params.instrumentGroup,
          depth: params.depth,
        )
        .listen(
          (book) => state = AsyncData(book),
          onError: (Object error, StackTrace stack) =>
              state = AsyncError<OrderBook?>(error, stack),
        );

    ref.onDispose(() async {
      _keepAliveTimer?.cancel();
      await _subscription?.cancel();
    });

    return null;
  }
}

final orderBookProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      OrderBookNotifier,
      OrderBook?,
      OrderBookParams
    >(OrderBookNotifier.new);
