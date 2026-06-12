import 'package:aloria/features/market/domain/trade_order.dart';

/// Сделка по портфелю из потока `TradesGetAndSubscribeV2`: факт покупки или
/// продажи — то, во что превратилась исполненная заявка.
class PortfolioTrade {
  const PortfolioTrade({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.side,
    required this.existing,
    this.orderId,
    this.date,
    this.qty,
    this.qtyUnits,
    this.price,
    this.volume,
    this.commission,
  });

  /// Идентификатор сделки.
  final String id;
  final String symbol;
  final String exchange;
  final OrderSide side;

  /// true — историческая сделка из снапшота, false — пришла вживую.
  final bool existing;

  /// Номер заявки, породившей сделку.
  final String? orderId;
  final DateTime? date;

  /// Количество в лотах.
  final int? qty;

  /// Количество в штуках.
  final int? qtyUnits;

  /// Цена сделки за единицу.
  final double? price;

  /// Объём сделки в валюте.
  final double? volume;
  final double? commission;

  static PortfolioTrade? fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final symbol = map['symbol']?.toString();
    final exchange = map['exchange']?.toString();
    if (id == null || symbol == null || exchange == null) return null;

    return PortfolioTrade(
      id: id,
      symbol: symbol,
      exchange: exchange,
      side: map['side']?.toString().toLowerCase() == 'sell'
          ? OrderSide.sell
          : OrderSide.buy,
      existing: (map['existing'] as bool?) ?? false,
      orderId: map['orderno']?.toString(),
      date: _parseDate(map['date']),
      qty: _parseInt(map['qty'] ?? map['qtyBatch']),
      qtyUnits: _parseInt(map['qtyUnits']),
      price: _parseDouble(map['price']),
      volume: _parseDouble(map['volume'] ?? map['value']),
      commission: _parseDouble(map['commission']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
