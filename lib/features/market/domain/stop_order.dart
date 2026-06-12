import 'package:aloria/features/market/domain/portfolio_order.dart';
import 'package:aloria/features/market/domain/trade_order.dart';

/// Условие срабатывания стоп-заявки относительно текущей цены.
enum StopCondition { more, less, moreOrEqual, lessOrEqual }

extension StopConditionX on StopCondition {
  /// Значение для API.
  String get apiValue => switch (this) {
        StopCondition.more => 'more',
        StopCondition.less => 'less',
        StopCondition.moreOrEqual => 'moreorequal',
        StopCondition.lessOrEqual => 'lessorequal',
      };

  static StopCondition from(String? value) => switch (value?.toLowerCase()) {
        'more' => StopCondition.more,
        'less' => StopCondition.less,
        'moreorequal' => StopCondition.moreOrEqual,
        _ => StopCondition.lessOrEqual,
      };
}

/// Условная (стоп) заявка из потока `StopOrdersGetAndSubscribeV2`.
/// Ждёт, пока цена дойдёт до цены срабатывания, и тогда выставляет
/// рыночную (`stop`) или лимитную (`stoplimit`) заявку.
class StopOrder {
  const StopOrder({
    required this.id,
    required this.symbol,
    required this.portfolio,
    required this.exchange,
    required this.side,
    required this.condition,
    required this.status,
    required this.isStopLimit,
    required this.existing,
    this.stopPrice,
    this.price,
    this.qty,
    this.transTime,
    this.endTime,
  });

  final String id;
  final String symbol;
  final String portfolio;
  final String exchange;
  final OrderSide side;
  final StopCondition condition;
  final OrderStatus status;

  /// true — после срабатывания выставится лимитная заявка, false — рыночная.
  final bool isStopLimit;
  final bool existing;

  /// Цена срабатывания.
  final double? stopPrice;

  /// Лимитная цена (для стоп-лимитной).
  final double? price;

  /// Количество в лотах.
  final int? qty;
  final DateTime? transTime;
  final DateTime? endTime;

  bool get isActive => status.isActive;

  static StopOrder? fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    final symbol = map['symbol']?.toString();
    final portfolio = map['portfolio']?.toString();
    final exchange = map['exchange']?.toString();
    if (id == null || symbol == null || portfolio == null || exchange == null) {
      return null;
    }

    return StopOrder(
      id: id,
      symbol: symbol,
      portfolio: portfolio,
      exchange: exchange,
      side: map['side']?.toString().toLowerCase() == 'sell'
          ? OrderSide.sell
          : OrderSide.buy,
      condition: StopConditionX.from(map['condition']?.toString()),
      status: OrderStatusX.from(map['status']?.toString()),
      isStopLimit:
          map['type']?.toString().toLowerCase().contains('limit') ?? false,
      existing: (map['existing'] as bool?) ?? false,
      stopPrice: _parseDouble(map['stopPrice']),
      price: _parseDouble(map['price']),
      qty: _parseInt(map['qty'] ?? map['qtyBatch']),
      transTime: _parseDate(map['transTime']),
      endTime: _parseDate(map['endTime']),
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
