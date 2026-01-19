import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/position.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final positionsProvider = StreamProvider<List<Position>>((ref) async* {
  final repo = await ref.watch(marketDataRepositoryProvider.future);
  yield* repo.watchPositions();
});

/// Keeps positions stream alive even when UI is not on the positions tab.
final positionsBootstrapperProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<Position>>>(
    positionsProvider,
    (previous, next) {},
  );
});
