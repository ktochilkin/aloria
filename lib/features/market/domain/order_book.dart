class OrderBookLevel {
  const OrderBookLevel({required this.price, required this.volume});

  final double price;
  final double volume;
}

class OrderBook {
  const OrderBook({
    required this.bids,
    required this.asks,
    required this.ts,
    required this.snapshot,
    required this.existing,
  });

  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;
  final DateTime ts;
  final bool snapshot;
  final bool existing;

  bool get isEmpty => bids.isEmpty && asks.isEmpty;

  OrderBook trimmed(int depth) {
    if (depth <= 0) return this;
    return OrderBook(
      bids: bids.take(depth).toList(),
      asks: asks.take(depth).toList(),
      ts: ts,
      snapshot: snapshot,
      existing: existing,
    );
  }

  static OrderBook? tryParse(Map<String, dynamic> event) {
    final payload = event['data'] is Map<String, dynamic>
        ? event['data'] as Map<String, dynamic>
        : event;
    final bids = _parseSide(payload['bids']);
    final asks = _parseSide(payload['asks']);
    if (bids.isEmpty && asks.isEmpty) return null;
    final ts =
        _parseTimestamp(
          payload['ms_timestamp'] ?? payload['timestamp'] ?? payload['time'],
        ) ??
        DateTime.now();
    final snapshot = payload['snapshot'] == true;
    final existing = payload['existing'] != false;
    return OrderBook(
      bids: bids,
      asks: asks,
      ts: ts,
      snapshot: snapshot,
      existing: existing,
    );
  }
}

List<OrderBookLevel> _parseSide(dynamic raw) {
  final result = <OrderBookLevel>[];
  if (raw is! List) return result;
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      final price = _toDouble(item['price'] ?? item['p']);
      final volume = _toDouble(item['volume'] ?? item['v']);
      if (price.isNaN || volume.isNaN) continue;
      result.add(OrderBookLevel(price: price, volume: volume));
    } else if (item is Map) {
      final map = item.cast<String, dynamic>();
      final price = _toDouble(map['price'] ?? map['p']);
      final volume = _toDouble(map['volume'] ?? map['v']);
      if (price.isNaN || volume.isNaN) continue;
      result.add(OrderBookLevel(price: price, volume: volume));
    }
  }
  return result;
}

DateTime? _parseTimestamp(dynamic value) {
  if (value is num) {
    final isSeconds = value < 1000000000000;
    final millis = isSeconds ? (value * 1000).toInt() : value.toInt();
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? double.nan;
  return double.nan;
}
