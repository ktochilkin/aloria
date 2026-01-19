import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/errors/error_types.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/features/auth/application/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final tokens = ref.read(authControllerProvider).tokens;
        if (tokens != null) {
          options.headers['Authorization'] = 'Bearer ${tokens.jwt}';
        }
        if (config.enableLogging) {
          appLogger.d('→ ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (config.enableLogging) {
          appLogger.d(
            '← ${response.statusCode} ${response.requestOptions.uri}',
          );
        }
        handler.next(response);
      },
      onError: (e, handler) async {
        if (config.enableLogging) {
          appLogger.e(
            '✖ ${e.requestOptions.uri}',
            error: e,
            stackTrace: e.stackTrace,
          );
        }
        final status = e.response?.statusCode ?? 0;
        final alreadyRetried = e.requestOptions.extra['authRetried'] == true;
        if (status == 401 && !alreadyRetried) {
          final refreshed = await ref
              .read(authControllerProvider.notifier)
              .refresh(force: true);
          if (refreshed != null) {
            final opts = e.requestOptions..extra['authRetried'] = true;
            opts.headers['Authorization'] = 'Bearer ${refreshed.jwt}';
            try {
              final clone = await dio.fetch(opts);
              return handler.resolve(clone);
            } catch (err, st) {
              appLogger.e(
                'Retry after refresh failed',
                error: err,
                stackTrace: st,
              );
            }
          }
        }
        handler.next(e);
      },
    ),
  );

  return dio;
});

extension DioSafe on Dio {
  Future<T> getSafe<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await get<T>(path, queryParameters: queryParameters);
      return res.data as T;
    } on DioException catch (e) {
      throw e.toTypedError();
    }
  }
}

extension DioErrorX on DioException {
  AppError toTypedError() {
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return const AppError.network('timeout');
    }
    final status = response?.statusCode ?? 0;
    if (status >= 500) return AppError.server('server_$status');
    if (status == 401) return const AppError.unauthorized();
    return AppError.network(message ?? 'network_error');
  }
}
