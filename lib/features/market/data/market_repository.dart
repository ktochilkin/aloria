import 'package:aloria/core/networking/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketSecurity {
  final String symbol;
  final String shortName;
  final String exchange;

  MarketSecurity({
    required this.symbol,
    required this.shortName,
    this.exchange = 'TEREX',
  });

  factory MarketSecurity.fromJson(Map<String, dynamic> json) => MarketSecurity(
    symbol: json['symbol'] as String? ?? '',
    shortName: json['shortname'] as String? ?? '',
    exchange: json['exchange'] as String? ?? 'TEREX',
  );
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
}

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MarketRepository(dio);
});
