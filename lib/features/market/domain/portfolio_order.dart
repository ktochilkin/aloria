import 'package:aloria/features/market/domain/trade_order.dart';

enum OrderStatus { working, filled, canceled, rejected, unknown }

extension OrderStatusX on OrderStatus {
  static OrderStatus from(String? value) {
    switch (value?.toLowerCase()) {
      case 'working':
        return OrderStatus.working;
      case 'filled':
        return OrderStatus.filled;
      case 'canceled':
        return OrderStatus.canceled;
      case 'rejected':
        return OrderStatus.rejected;
      default:
        return OrderStatus.unknown;
    }
  }

  bool get isActive => this == OrderStatus.working;
}

class IcebergDetails {
  const IcebergDetails({
    required this.creationFixedQuantity,
    required this.creationVarianceQuantity,
    required this.visibleQuantity,
    required this.visibleQuantityBatch,
    required this.visibleFilledQuantity,
    required this.visibleFilledQuantityBatch,
  });

  final int? creationFixedQuantity;
  final int? creationVarianceQuantity;
  final int? visibleQuantity;
  final int? visibleQuantityBatch;
  final int? visibleFilledQuantity;
  final int? visibleFilledQuantityBatch;

  factory IcebergDetails.fromMap(Map<String, dynamic> map) {
    return IcebergDetails(
      creationFixedQuantity: _parseInt(map['creationFixedQuantity']),
      creationVarianceQuantity: _parseInt(map['creationVarianceQuantity']),
      visibleQuantity: _parseInt(map['visibleQuantity']),
      visibleQuantityBatch: _parseInt(map['visibleQuantityBatch']),
      visibleFilledQuantity: _parseInt(map['visibleFilledQuantity']),
      visibleFilledQuantityBatch: _parseInt(map['visibleFilledQuantityBatch']),
    );
  }
}

class ClientOrder {
  const ClientOrder({
    required this.id,
    required this.symbol,
    required this.brokerSymbol,
    required this.portfolio,
    required this.exchange,
    required this.type,
    required this.side,
    required this.status,
    required this.existing,
    this.comment,
    this.transTime,
    this.updateTime,
    this.endTime,
    this.qtyUnits,
    this.qtyBatch,
    this.qty,
    this.filledQtyUnits,
    this.filledQtyBatch,
    this.filled,
    this.price,
    this.timeInForce,
    this.iceberg,
    this.volume,
  });

  final String id;
  final String symbol;
  final String brokerSymbol;
  final String portfolio;
  final String exchange;
  final OrderType type;
  final OrderSide side;
  final OrderStatus status;
  final bool existing;
  final String? comment;
  final DateTime? transTime;
  final DateTime? updateTime;
  final DateTime? endTime;
  final int? qtyUnits;
  final int? qtyBatch;
  final int? qty;
  final double? filledQtyUnits;
  final double? filledQtyBatch;
  final double? filled;
  final double? price;
  final String? timeInForce;
  final IcebergDetails? iceberg;
  final double? volume;

  bool get isActive => status.isActive;

  ClientOrder copyWith({
    OrderStatus? status,
    double? filledQtyUnits,
    double? filledQtyBatch,
    double? filled,
    double? price,
    double? volume,
    DateTime? updateTime,
  }) {
    return ClientOrder(
      id: id,
      symbol: symbol,
      brokerSymbol: brokerSymbol,
      portfolio: portfolio,
      exchange: exchange,
      type: type,
      side: side,
      status: status ?? this.status,
      existing: existing,
      comment: comment,
      transTime: transTime,
      updateTime: updateTime ?? this.updateTime,
      endTime: endTime,
      qtyUnits: qtyUnits,
      qtyBatch: qtyBatch,
      qty: qty,
      filledQtyUnits: filledQtyUnits ?? this.filledQtyUnits,
      filledQtyBatch: filledQtyBatch ?? this.filledQtyBatch,
      filled: filled ?? this.filled,
      price: price ?? this.price,
      timeInForce: timeInForce,
      iceberg: iceberg,
      volume: volume ?? this.volume,
    );
  }

  static ClientOrder? fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final symbol = map['symbol']?.toString();
    final portfolio = map['portfolio']?.toString();
    final exchange = map['exchange']?.toString();
    final typeRaw = map['type']?.toString().toLowerCase();
    final sideRaw = map['side']?.toString().toLowerCase();
    if (id == null || symbol == null || portfolio == null || exchange == null) {
      return null;
    }

    return ClientOrder(
      id: id,
      symbol: symbol,
      brokerSymbol: map['brokerSymbol']?.toString() ?? '$exchange:$symbol',
      portfolio: portfolio,
      exchange: exchange,
      type: typeRaw == 'limit' ? OrderType.limit : OrderType.market,
      side: sideRaw == 'sell' ? OrderSide.sell : OrderSide.buy,
      status: OrderStatusX.from(map['status']?.toString()),
      existing: (map['existing'] as bool?) ?? false,
      comment: map['comment']?.toString(),
      transTime: _parseDate(map['transTime']),
      updateTime: _parseDate(map['updateTime']),
      endTime: _parseDate(map['endTime']),
      qtyUnits: _parseInt(map['qtyUnits']),
      qtyBatch: _parseInt(map['qtyBatch'] ?? map['qty']),
      qty: _parseInt(map['qty']),
      filledQtyUnits: _parseDouble(map['filledQtyUnits']),
      filledQtyBatch: _parseDouble(map['filledQtyBatch']),
      filled: _parseDouble(map['filled']),
      price: _parseDouble(map['price']),
      timeInForce: map['timeInForce']?.toString(),
      iceberg: map['iceberg'] is Map<String, dynamic>
          ? IcebergDetails.fromMap(map['iceberg'] as Map<String, dynamic>)
          : null,
      volume: _parseDouble(map['volume']),
    );
  }
}

int? _parseInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _parseDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}
