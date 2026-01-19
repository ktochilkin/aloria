class Candle {
  final DateTime ts;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.ts,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory Candle.fromMap(Map<String, dynamic> map) {
    final tsRaw = map['time'] ?? map['timestamp'] ?? map['t'];
    DateTime ts;
    if (tsRaw is num) {
      final isSeconds = tsRaw < 1000000000000;
      final millis = isSeconds ? (tsRaw * 1000).toInt() : tsRaw.toInt();
      ts = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    } else if (tsRaw is String && DateTime.tryParse(tsRaw) != null) {
      ts = DateTime.parse(tsRaw).toLocal();
    } else {
      ts = DateTime.now();
    }
    double toDouble(dynamic v) => v is num ? v.toDouble() : double.nan;
    return Candle(
      ts: ts,
      open: toDouble(map['open'] ?? map['o'] ?? map['Open']),
      high: toDouble(map['high'] ?? map['h'] ?? map['High']),
      low: toDouble(map['low'] ?? map['l'] ?? map['Low']),
      close: toDouble(map['close'] ?? map['c'] ?? map['lastPrice'] ?? map['price']),
      volume: toDouble(map['volume'] ?? map['v'] ?? map['Volume'] ?? 0),
    );
  }

  bool get isValid =>
      !open.isNaN && !high.isNaN && !low.isNaN && !close.isNaN && high >= low;
}
