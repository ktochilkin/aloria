import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/market_news.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Репозиторий новостей экономического мира (aloria-api).
///
/// Раньше новости брались из торгового `/news/graphql` (фильтр только по
/// тикеру, не расширяемо). Теперь — из aloria-api: фильтр по symbol/сектору/типу,
/// данные несут тональность и тип события. Писатель на шаге 1 — мок-сидер бэка,
/// позже — ИИ-режиссёр.
class MarketNewsRepository {
  MarketNewsRepository({
    required String baseUrl,
    required bool enableLogging,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 12),
            sendTimeout: const Duration(seconds: 6),
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    if (enableLogging) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, h) {
            appLogger.w('news ✖ ${e.requestOptions.uri}: ${e.message}');
            h.next(e);
          },
        ),
      );
    }
  }

  final Dio _dio;

  /// Лента новостей. Фильтры опциональны: [symbol] — по инструменту,
  /// [sector] — по сектору, [type] — по типу события.
  Future<List<MarketNews>> fetchNews({
    String? symbol,
    String? sector,
    String? type,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/market/news',
        queryParameters: {
          if (symbol != null && symbol.isNotEmpty) 'symbol': symbol,
          if (sector != null && sector.isNotEmpty) 'sector': sector,
          if (type != null && type.isNotEmpty) 'type': type,
          'limit': limit,
        },
      );
      return (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MarketNews.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw e.toTypedError();
    }
  }
}

final marketNewsRepositoryProvider = Provider<MarketNewsRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return MarketNewsRepository(
    baseUrl: config.aloriaApiBaseUrl,
    enableLogging: config.enableLogging,
  );
});
