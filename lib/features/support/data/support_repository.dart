import 'dart:convert';

import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:aloria/features/learn/application/learning_providers.dart';
import 'package:aloria/features/support/domain/support_ticket.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Репозиторий обращений в поддержку (aloria-api).
///
/// Создание обращения с подробным контекстом для разбора и список своих
/// обращений со статусами. Ответ пользователю приходит на почту — в
/// приложении видно только статус и текст ответа.
class SupportRepository {
  SupportRepository({
    required String baseUrl,
    required bool enableLogging,
    required this.portfolioId,
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
            appLogger.w('support ✖ ${e.requestOptions.uri}: ${e.message}');
            h.next(e);
          },
        ),
      );
    }
  }

  final Dio _dio;
  final String portfolioId;

  /// Создаёт обращение. [context] — снимок состояния для разбора
  /// (параметры заявки, покупательная способность, позиции и т.п.).
  Future<void> createTicket({
    required String subject,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? context,
    String? comment,
  }) async {
    await _dio.post<void>(
      '/api/v1/support/tickets',
      queryParameters: {'portfolioId': portfolioId},
      data: {
        'subject': subject,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'context': context == null ? null : jsonEncode(context),
        'comment': comment,
      },
    );
  }

  /// Свои обращения, свежие сверху.
  Future<List<SupportTicket>> fetchTickets() async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/support/tickets',
      queryParameters: {'portfolioId': portfolioId},
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromMap)
        .whereType<SupportTicket>()
        .toList(growable: false);
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  return SupportRepository(
    baseUrl: config.aloriaApiBaseUrl,
    enableLogging: config.enableLogging,
    portfolioId: ref.watch(aloriaPortfolioIdProvider),
  );
});

/// Список обращений пользователя для экрана «Мои обращения».
final supportTicketsProvider = FutureProvider<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).fetchTickets(),
);
