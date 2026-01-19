class Position {
  final String symbol;
  final String exchange;
  final double quantity;
  final double averagePrice;
  final String currency;
  final double volume;
  final double currentVolume;

  const Position({
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.currency,
    required this.volume,
    required this.currentVolume,
  });

  factory Position.fromMap(Map<String, dynamic> map) {
    String asString(dynamic v) => v?.toString() ?? '';
    double asDouble(dynamic v) => v is num ? v.toDouble() : 0;

    return Position(
      symbol: asString(map['symbol'] ?? map['code'] ?? map['ticker']),
      exchange: asString(map['exchange'] ?? map['board'] ?? 'MOEX'),
      quantity: asDouble(
        map['qtyTFuture'] ??
            map['qty'] ??
            map['quantity'] ??
            map['balance'] ??
            map['qtyLots'],
      ),
      averagePrice: asDouble(
        map['avgPrice'] ?? map['averagePrice'] ?? map['price'] ?? map['vwap'],
      ),
      currency: asString(map['currency'] ?? 'RUB'),
      volume: asDouble(map['volume']),
      currentVolume: asDouble(map['currentVolume']),
    );
  }
}
