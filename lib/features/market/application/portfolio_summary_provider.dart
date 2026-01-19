import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/portfolio_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final portfolioSummaryProvider =
    StreamProvider<PortfolioSummary>((ref) async* {
  final repo = await ref.watch(marketDataRepositoryProvider.future);
  yield* repo.watchPortfolioSummary();
});

/// Keeps portfolio summary stream alive even when UI tab is not visible.
final portfolioSummaryBootstrapperProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<PortfolioSummary>>(
    portfolioSummaryProvider,
    (previous, next) {},
  );
});
