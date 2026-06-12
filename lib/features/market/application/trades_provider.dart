import 'package:aloria/features/market/data/market_data_repository.dart';
import 'package:aloria/features/market/domain/portfolio_trade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Сделки по портфелю — снапшот истории и живые исполнения.
final tradesProvider = StreamProvider<List<PortfolioTrade>>((ref) async* {
  final repo = await ref.watch(marketDataRepositoryProvider.future);
  yield* repo.watchTrades();
});
