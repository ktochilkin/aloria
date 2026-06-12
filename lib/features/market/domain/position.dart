class Position {
  final String symbol;
  final String exchange;
  final double quantity;
  final double averagePrice;
  final String currency;
  final double volume;
  final double currentVolume;
  final double? unrealisedPl;

  /// Человеческое название инструмента («Сбербанк России ПАО ао»).
  final String? shortName;

  /// Количество в штуках (единицах), а не в лотах.
  final double? qtyUnits;

  /// Размер лота инструмента.
  final double? lotSize;

  /// Количество на момент открытия дня (в штуках).
  final double? openUnits;

  /// Доступно уже сегодня (T0): расчёты по этим бумагам завершены.
  final double? qtyT0;

  /// Станет доступно завтра (T1) — куплено сегодня, расчёт ещё идёт.
  final double? qtyT1;

  /// Станет доступно послезавтра (T2).
  final double? qtyT2;

  /// Нереализованный результат за сегодняшний день.
  final double? dailyUnrealisedPl;

  const Position({
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.currency,
    required this.volume,
    required this.currentVolume,
    this.unrealisedPl,
    this.shortName,
    this.qtyUnits,
    this.lotSize,
    this.openUnits,
    this.qtyT0,
    this.qtyT1,
    this.qtyT2,
    this.dailyUnrealisedPl,
  });

  factory Position.fromMap(Map<String, dynamic> map) {
    String asString(dynamic v) => v?.toString() ?? '';
    double asDouble(dynamic v) => v is num ? v.toDouble() : 0;
    double? asNullableDouble(dynamic v) => v is num ? v.toDouble() : null;

    return Position(
      symbol: asString(map['symbol'] ?? map['code'] ?? map['ticker']),
      exchange: asString(map['exchange'] ?? map['board'] ?? 'TEREX'),
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
      unrealisedPl: asNullableDouble(map['unrealisedPl']),
      shortName: map['shortName']?.toString(),
      qtyUnits: asNullableDouble(map['qtyUnits']),
      lotSize: asNullableDouble(map['lotSize']),
      openUnits: asNullableDouble(map['openUnits']),
      qtyT0: asNullableDouble(map['qtyT0']),
      qtyT1: asNullableDouble(map['qtyT1']),
      qtyT2: asNullableDouble(map['qtyT2']),
      dailyUnrealisedPl: asNullableDouble(map['dailyUnrealisedPl']),
    );
  }
}
