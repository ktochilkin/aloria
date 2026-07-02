import 'dart:async';

import 'package:aloria/features/market/data/market_news_repository.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдеры новостей. Мир Алории живой (новости публикует ИИ-режиссёр),
/// поэтому провайдеры сами перезапрашиваются раз в минуту — лента и макро
/// не «замирают» до перезапуска приложения.
const _autoRefresh = Duration(seconds: 60);

final marketNewsProvider = FutureProvider.autoDispose
    .family<List<MarketNews>, String>((ref, symbol) {
      ref.keepAlive();
      final timer = Timer(_autoRefresh, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      final repo = ref.watch(marketNewsRepositoryProvider);
      return repo.fetchNews(symbol: symbol);
    });

final marketAllNewsProvider = FutureProvider.autoDispose<List<MarketNews>>((
  ref,
) {
  ref.keepAlive();
  final timer = Timer(_autoRefresh, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final repo = ref.watch(marketNewsRepositoryProvider);
  return repo.fetchNews(limit: 120);
});
