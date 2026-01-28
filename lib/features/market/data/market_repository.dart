import 'package:aloria/core/networking/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketSecurity {
  final String symbol;
  final String shortName;
  final String exchange;
  final double? lastPrice;
  final double? changePercent;

  MarketSecurity({
    required this.symbol,
    required this.shortName,
    this.exchange = 'TEREX',
    this.lastPrice,
    this.changePercent,
  });

  factory MarketSecurity.fromJson(Map<String, dynamic> json) => MarketSecurity(
    symbol: json['symbol'] as String? ?? '',
    shortName: json['shortname'] as String? ?? '',
    exchange: json['exchange'] as String? ?? 'TEREX',
    lastPrice: json['last_price'] != null
        ? (json['last_price'] as num).toDouble()
        : null,
    changePercent: json['change_percent'] != null
        ? (json['change_percent'] as num).toDouble()
        : null,
  );

  MarketSecurity copyWith({
    String? symbol,
    String? shortName,
    String? exchange,
    double? lastPrice,
    double? changePercent,
  }) {
    return MarketSecurity(
      symbol: symbol ?? this.symbol,
      shortName: shortName ?? this.shortName,
      exchange: exchange ?? this.exchange,
      lastPrice: lastPrice ?? this.lastPrice,
      changePercent: changePercent ?? this.changePercent,
    );
  }
}

class MarketRepository {
  MarketRepository(this._dio);

  final Dio _dio;

  Future<List<MarketSecurity>> fetchSecurities({int limit = 15}) async {
    final data = await _dio.getSafe<List<dynamic>>(
      '/md/v2/Securities',
      queryParameters: {'limit': limit, 'exchange': 'TEREX', 'query': 'RUALR'},
    );
    return data
        .map((e) => MarketSecurity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return [];

    // Construct the comma-separated list of EXCHANGE:SYMBOL
    // Assuming all are TEREX for now based on fetchSecurities,
    // but better to use the instrument's known exchange if we had that detail while building the list.
    // However, the fetchSecurities sets exchange to 'TEREX' by default.
    // The example uses "TEREX:BRED".

    final query = symbols.map((s) => 'TEREX:$s').join(',');

    final data = await _dio.getSafe<List<dynamic>>(
      '/md/v2/Securities/$query/quotes',
    );

    return data.map((e) => e as Map<String, dynamic>).toList();
  }
}

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MarketRepository(dio);
});
