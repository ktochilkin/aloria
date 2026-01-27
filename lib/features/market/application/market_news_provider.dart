import 'package:aloria/features/market/data/market_news_repository.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final marketNewsProvider = FutureProvider.autoDispose
    .family<List<MarketNews>, String>((ref, symbol) async {
      ref.keepAlive();
      final repo = ref.watch(marketNewsRepositoryProvider);
      return repo.fetchNews(symbol: symbol);
    });

final marketAllNewsProvider = FutureProvider.autoDispose<List<MarketNews>>((
  ref,
) async {
  ref.keepAlive();
  final repo = ref.watch(marketNewsRepositoryProvider);
  return repo.fetchNews(limit: 50);
});
