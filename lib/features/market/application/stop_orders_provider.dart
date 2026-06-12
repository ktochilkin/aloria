import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/stop_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Условные (стоп) заявки по портфелю.
final stopOrdersProvider = StreamProvider<List<StopOrder>>((ref) async* {
  final repo = await ref.watch(marketDataRepositoryProvider.future);
  yield* repo.watchStopOrders();
});

/// Отмена условной заявки (DELETE с пометкой stop).
final cancelStopOrderProvider = Provider<
    Future<void> Function({
      required String orderId,
      required String portfolio,
      required String exchange,
    })>((ref) {
  return ({
    required String orderId,
    required String portfolio,
    required String exchange,
  }) async {
    final repo = await ref.read(marketDataRepositoryProvider.future);
    await repo.cancelOrder(
      orderId: orderId,
      portfolio: portfolio,
      exchange: exchange,
      stop: true,
    );
  };
});
