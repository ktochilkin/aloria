class PortfolioSummary {
  final double buyingPower;
  final String currency;

  const PortfolioSummary({required this.buyingPower, required this.currency});

  static PortfolioSummary? tryParse(Map<String, dynamic> map) {
    double asDouble(dynamic v) => v is num ? v.toDouble() : 0;
    final byCurrency = map['buyingPowerByCurrency'];
    final hasPower = map.containsKey('buyingPower') ||
        (byCurrency is List && byCurrency.isNotEmpty);
    if (!hasPower) return null;

    var buyingPower = asDouble(map['buyingPower']);
    if (buyingPower == 0 && byCurrency is List && byCurrency.isNotEmpty) {
      final first = byCurrency.first;
      if (first is Map && first['buyingPower'] != null) {
        buyingPower = asDouble(first['buyingPower']);
      }
    }
    String currency = 'RUB';
    if (byCurrency is List && byCurrency.isNotEmpty) {
      final first = byCurrency.first;
      if (first is Map && first['currency'] is String) {
        currency = first['currency'] as String;
      }
    } else if (map['currency'] is String) {
      currency = map['currency'] as String;
    }

    return PortfolioSummary(buyingPower: buyingPower, currency: currency);
  }
}
