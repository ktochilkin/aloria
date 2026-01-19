import 'dart:convert';

class MarketPrice {
  final String instrumentId;
  final double price;
  final DateTime ts;

  const MarketPrice({
    required this.instrumentId,
    required this.price,
    required this.ts,
  });

  MarketPrice copyWith({String? instrumentId, double? price, DateTime? ts}) {
    return MarketPrice(
      instrumentId: instrumentId ?? this.instrumentId,
      price: price ?? this.price,
      ts: ts ?? this.ts,
    );
  }

  Map<String, dynamic> toJson() => {
    'instrumentId': instrumentId,
    'price': price,
    'ts': ts.toIso8601String(),
  };

  static MarketPrice? tryParse(String instrumentId, Map<String, dynamic> json) {
    // Some feeds wrap payload in a `data` field.
    final payload = json['data'] is Map<String, dynamic>
      ? (json['data'] as Map<String, dynamic>)
      : json;

    final raw = payload['last_price'] ??
      payload['lastPrice'] ??
      payload['price'] ??
      payload['last'] ??
      payload['p'];
    final num? parsed = raw is num
        ? raw
        : raw is String
        ? num.tryParse(raw)
        : null;
    if (parsed == null) return null;
    final tsRaw = payload['timestamp'] ?? payload['time'] ?? payload['ts'];
    final DateTime? ts = tsRaw is num
        ? (() {
            final isSeconds = tsRaw < 1000000000000;
            final millis = isSeconds ? (tsRaw * 1000).toInt() : tsRaw.toInt();
            return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
                .toLocal();
          })()
        : tsRaw is String
            ? DateTime.tryParse(tsRaw)?.toLocal()
            : null;
    return MarketPrice(
      instrumentId: instrumentId,
      price: parsed.toDouble(),
      ts: ts ?? DateTime.now(),
    );
  }

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      instrumentId: json['instrumentId'] as String,
      price: (json['price'] as num).toDouble(),
      ts: DateTime.parse(json['ts'] as String),
    );
  }

  static List<MarketPrice> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MarketPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<MarketPrice> prices) {
    return jsonEncode(prices.map((e) => e.toJson()).toList());
  }
}
