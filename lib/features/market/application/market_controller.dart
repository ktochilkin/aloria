import 'dart:async';

import 'package:aloria/features/market/data/market_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketSecuritiesNotifier
    extends StateNotifier<AsyncValue<List<MarketSecurity>>> {
  MarketSecuritiesNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    _init();
  }

  final MarketRepository _repository;
  Timer? _timer;

  Future<void> _init() async {
    try {
      final securities = await _repository.fetchSecurities();
      state = AsyncValue.data(securities);
      _startPolling();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchQuotes(); // Fetch immediately
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchQuotes());
  }

  Future<void> _fetchQuotes() async {
    final currentList = state.valueOrNull;
    if (currentList == null || currentList.isEmpty) return;

    try {
      final symbols = currentList.map((e) => e.symbol).toList();
      final quotes = await _repository.fetchQuotes(symbols);

      // Map quotes to a map for O(1) lookup
      // Key: symbol, Value: quote map
      final quotesMap = {for (var q in quotes) q['symbol'] as String: q};

      final updatedList = currentList.map((security) {
        final quote = quotesMap[security.symbol];
        if (quote != null) {
          return security.copyWith(
            lastPrice: (quote['last_price'] as num?)?.toDouble(),
            changePercent: (quote['change_percent'] as num?)?.toDouble(),
          );
        }
        return security;
      }).toList();

      if (mounted) {
        state = AsyncValue.data(updatedList);
      }
    } catch (e) {
      // If quotes fail, we keep old state but maybe log it?
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final marketSecuritiesProvider =
    StateNotifierProvider.autoDispose<
      MarketSecuritiesNotifier,
      AsyncValue<List<MarketSecurity>>
    >((ref) {
      final repo = ref.watch(marketRepositoryProvider);
      return MarketSecuritiesNotifier(repo);
    });
