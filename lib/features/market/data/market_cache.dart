import 'package:aloria/core/storage/storage.dart';
import 'package:aloria/features/market/domain/market_price.dart';

class MarketCache {
  MarketCache({required Storage storage}) : _storage = storage;

  final Storage _storage;
  static const _cachePrefix = 'quote_cache_';
  static const _maxHistory = 200;

  Future<List<MarketPrice>> loadHistory(String symbol) async {
    final raw = await _storage.read('$_cachePrefix$symbol');
    if (raw == null) return [];
    try {
      final all = MarketPrice.listFromJson(raw);
      // Фильтруем только цены с нужным instrumentId
      return all.where((p) => p.instrumentId == symbol).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendPrice(String symbol, MarketPrice price) async {
    // Загружаем все данные по этому symbol (может содержать данные разных instrumentId)
    final raw = await _storage.read('$_cachePrefix$symbol');
    final allHistory = raw != null
        ? MarketPrice.listFromJson(raw)
        : <MarketPrice>[];

    // Добавляем новую цену
    final updated = [...allHistory, price];

    // Обрезаем старые данные, сохраняя последние _maxHistory записей
    final trimmed = updated.length > _maxHistory
        ? updated.sublist(updated.length - _maxHistory)
        : updated;

    await _storage.write(
      '$_cachePrefix$symbol',
      MarketPrice.listToJson(trimmed),
    );
  }
}
