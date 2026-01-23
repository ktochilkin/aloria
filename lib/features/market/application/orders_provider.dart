import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ordersProvider = StreamProvider<List<ClientOrder>>((ref) async* {
  final repo = await ref.watch(marketDataRepositoryProvider.future);
  yield* repo.watchOrders();
});

/// Keeps orders stream alive even when UI tab is not visible.
final ordersBootstrapperProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<ClientOrder>>>(
    ordersProvider,
    (previous, next) {},
  );
});
