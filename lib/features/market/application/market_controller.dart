import 'package:aloria/features/market/data/market_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketSecuritiesProvider = FutureProvider((ref) {
  final repo = ref.read(marketRepositoryProvider);
  return repo.fetchSecurities();
});
