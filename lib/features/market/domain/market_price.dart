import 'dart:convert';

class MarketPrice {
  final String instrumentId;
  final double price;
  final DateTime ts;

  // Расширенные поля котировки (формат Simple/Heavy QuotesSubscribe). Несут
  // данные для богатой шапки инструмента; опциональны — из кэша/истории придут
  // null, заполняются живым потоком котировок.
  final String? description; // название компании/инструмента
  final String? currency;
  final String? instrumentType; // CS, PS, BOND, ...
  final double? prevClose;
  final double? open;
  final double? high;
  final double? low;
  final double? change;
  final double? changePercent;
  final double? volume;
  final double? bid;
  final double? ask;
  final double? lotSize;
  final double? lotValue;
  final double? faceValue;
  final double? yieldValue;
  final double? minStep; // минимальный шаг цены (из детали инструмента)

  const MarketPrice({
    required this.instrumentId,
    required this.price,
    required this.ts,
    this.description,
    this.currency,
    this.instrumentType,
    this.prevClose,
    this.open,
    this.high,
    this.low,
    this.change,
    this.changePercent,
    this.volume,
    this.bid,
    this.ask,
    this.lotSize,
    this.lotValue,
    this.faceValue,
    this.yieldValue,
    this.minStep,
  });

  MarketPrice copyWith({String? instrumentId, double? price, DateTime? ts}) {
    return MarketPrice(
      instrumentId: instrumentId ?? this.instrumentId,
      price: price ?? this.price,
      ts: ts ?? this.ts,
      description: description,
      currency: currency,
      instrumentType: instrumentType,
      prevClose: prevClose,
      open: open,
      high: high,
      low: low,
      change: change,
      changePercent: changePercent,
      volume: volume,
      bid: bid,
      ask: ask,
      lotSize: lotSize,
      lotValue: lotValue,
      faceValue: faceValue,
      yieldValue: yieldValue,
      minStep: minStep,
    );
  }

  Map<String, dynamic> toJson() => {
    'instrumentId': instrumentId,
    'price': price,
    'ts': ts.toIso8601String(),
  };

  /// Достаёт число из payload по нескольким возможным ключам (snake/camel).
  static double? _num(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      final v = p[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = num.tryParse(v);
        if (parsed != null) return parsed.toDouble();
      }
    }
    return null;
  }

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
      description: payload['description'] as String?,
      currency: payload['currency'] as String?,
      instrumentType: payload['type'] as String?,
      prevClose: _num(payload, ['prev_close_price', 'prevClosePrice']),
      open: _num(payload, ['open_price', 'openPrice']),
      high: _num(payload, ['high_price', 'highPrice']),
      low: _num(payload, ['low_price', 'lowPrice']),
      change: _num(payload, ['change']),
      changePercent: _num(payload, ['change_percent', 'changePercent']),
      volume: _num(payload, ['volume']),
      bid: _num(payload, ['bid']),
      ask: _num(payload, ['ask']),
      lotSize: _num(payload, ['lotsize', 'lotSize']),
      lotValue: _num(payload, ['lotvalue', 'lotValue']),
      faceValue: _num(payload, ['facevalue', 'faceValue']),
      yieldValue: _num(payload, ['yield']),
      minStep: _num(payload, ['minstep', 'minStep', 'pricestep', 'priceStep']),
    );
  }

  /// Парсит статическую деталь инструмента (`/md/v2/Securities/{ex}/{sym}`),
  /// где НЕТ `last_price` — поэтому цена опциональна (0 по умолчанию). Несёт
  /// minStep, lotSize, description, currency, type и т.п.
  static MarketPrice? tryParseDetail(
    String instrumentId,
    Map<String, dynamic> json,
  ) {
    final payload = json['data'] is Map<String, dynamic>
        ? (json['data'] as Map<String, dynamic>)
        : json;
    final last = _num(payload, ['last_price', 'lastPrice', 'price']);
    return MarketPrice(
      instrumentId: instrumentId,
      price: last ?? 0,
      ts: DateTime.now(),
      description: payload['description'] as String?,
      currency: payload['currency'] as String?,
      instrumentType: payload['type'] as String?,
      lotSize: _num(payload, ['lotsize', 'lotSize']),
      faceValue: _num(payload, ['facevalue', 'faceValue']),
      yieldValue: _num(payload, ['yield']),
      minStep: _num(payload, ['minstep', 'minStep', 'pricestep', 'priceStep']),
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
