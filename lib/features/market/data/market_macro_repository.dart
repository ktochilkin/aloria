import 'dart:async';

import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/core/networking/api_client.dart';
import 'package:aloria/features/market/domain/macro_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Репозиторий макросостояния экономического мира (aloria-api).
class MarketMacroRepository {
  MarketMacroRepository({
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
            appLogger.w('macro ✖ ${e.requestOptions.uri}: ${e.message}');
            h.next(e);
          },
        ),
      );
    }
  }

  final Dio _dio;

  Future<MacroState> fetchMacroState() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/macro/state');
      return MacroState.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw e.toTypedError();
    }
  }
}

final marketMacroRepositoryProvider = Provider<MarketMacroRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return MarketMacroRepository(
    baseUrl: config.aloriaApiBaseUrl,
    enableLogging: config.enableLogging,
  );
});

final macroStateProvider = FutureProvider.autoDispose<MacroState>((ref) {
  ref.keepAlive();
  // Мир живой: день цикла и режим двигает режиссёр — перечитываем раз в минуту.
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(marketMacroRepositoryProvider).fetchMacroState();
});
