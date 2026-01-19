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

  @override
  FutureOr<OrderBook?> build(OrderBookParams params) async {
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
      await _subscription?.cancel();
      _subscription = null;
    });

    return null;
  }
}

final orderBookProvider = AutoDisposeAsyncNotifierProviderFamily<
  OrderBookNotifier,
  OrderBook?,
  OrderBookParams
>(OrderBookNotifier.new);
