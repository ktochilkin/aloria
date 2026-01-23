enum OrderSide { buy, sell }

enum OrderType { market, limit }

class TradeOrder {
  static const defaultPortfolio = 'T00013';
  static const defaultTimeInForce = 'oneday';

  final String symbol;
  final String exchange;
  final String portfolio;
  final String timeInForce;
  final OrderSide side;
  final OrderType type;
  final double quantity;
  final double? limitPrice;

  const TradeOrder({
    required this.symbol,
    required this.exchange,
    this.portfolio = defaultPortfolio,
    this.timeInForce = defaultTimeInForce,
    required this.side,
    required this.type,
    required this.quantity,
    this.limitPrice,
  });

  Map<String, dynamic> toJson() {
    final base = <String, dynamic>{
      'side': side.name,
      'quantity': quantity,
      'instrument': {'symbol': symbol, 'exchange': exchange},
      'user': {'portfolio': portfolio},
      'timeInForce': timeInForce,
      'instrumentGroup': 'TEREX',
    };

    if (type == OrderType.limit && limitPrice != null) {
      base['price'] = limitPrice;
    }
    return base;
  }
}
