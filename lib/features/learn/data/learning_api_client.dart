import 'package:aloria/core/env/env.dart';
import 'package:aloria/core/logging/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HTTP-клиент для aloria-api (учебный контент, тесты, прогресс, ачивки).
class LearningApiClient {
  LearningApiClient({required this.baseUrl, required this.enableLogging})
      : _dio = Dio(
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
          onRequest: (o, h) {
            appLogger.d('learn → ${o.method} ${o.uri}');
            h.next(o);
          },
          onError: (e, h) {
            appLogger.w(
              'learn ✖ ${e.requestOptions.uri}: ${e.message}',
            );
            h.next(e);
          },
        ),
      );
    }
  }

  final String baseUrl;
  final bool enableLogging;
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchSections({String? portfolioId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/learning/sections',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchSection(
    String slug, {
    String? portfolioId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/learning/sections/$slug',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> fetchLesson(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/learning/lessons/$id',
    );
    return res.data ?? const {};
  }

  Future<void> markLessonComplete({
    required String lessonId,
    required String portfolioId,
  }) async {
    await _dio.post<void>(
      '/api/v1/learning/lessons/$lessonId/complete',
      queryParameters: {'portfolioId': portfolioId},
    );
  }

  Future<Map<String, dynamic>> fetchQuiz(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/quizzes/$id',
    );
    return res.data ?? const {};
  }

  /// Список standalone-тестов для экрана «Пополнить».
  Future<List<Map<String, dynamic>>> fetchTopUpQuizzes() async {
    final res = await _dio.get<List<dynamic>>('/api/v1/topup/quizzes');
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Отправляет ответы на проверку. Один и тот же [idempotencyKey]
  /// гарантирует, что повторный вызов вернёт уже выданный результат.
  Future<Map<String, dynamic>> submitQuizAttempt({
    required String quizId,
    required String portfolioId,
    required List<Map<String, dynamic>> answers,
    required String idempotencyKey,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/quizzes/$quizId/attempts',
      queryParameters: {'portfolioId': portfolioId},
      data: {'answers': answers},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> fetchProgress(String portfolioId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/me/progress',
      queryParameters: {'portfolioId': portfolioId},
    );
    return res.data ?? const {};
  }

  /// Идемпотентно регистрирует факт открытия первой позиции у пользователя.
  /// Бэкенд сам проверит, что событие ещё не было записано.
  Future<void> reportFirstPosition(String portfolioId) async {
    await _dio.post<void>(
      '/api/v1/me/events/first-position',
      queryParameters: {'portfolioId': portfolioId},
    );
  }

  /// Оценка карточки recall (разнесённое повторение). Возвращает интервал в
  /// днях до следующего повторения, если бэкенд его вернул.
  Future<int?> gradeReview({
    required String lessonId,
    required bool remembered,
    required String portfolioId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/me/reviews/$lessonId/grade',
      queryParameters: {'portfolioId': portfolioId},
      data: {'remembered': remembered},
    );
    return (res.data?['intervalDays'] as num?)?.toInt();
  }

  /// Карточки recall, которые пора повторить (NextDueAt <= сейчас).
  Future<List<Map<String, dynamic>>> fetchDueReviews(String portfolioId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/me/reviews/due',
      queryParameters: {'portfolioId': portfolioId},
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Регистрирует push-токен устройства за пользователем (portfolioId).
  Future<void> registerDevice({
    required String token,
    required String platform,
    required String portfolioId,
  }) async {
    await _dio.post<void>(
      '/api/v1/me/devices',
      queryParameters: {'portfolioId': portfolioId},
      data: {'token': token, 'platform': platform},
    );
  }

  /// Отписывает устройство (logout / выключение пушей).
  Future<void> unregisterDevice(String token) async {
    await _dio.delete<void>('/api/v1/me/devices/$token');
  }

  /// Спиральный курс (r11). Возвращает список этапов с прогрессом
  /// пользователя.
  Future<List<Map<String, dynamic>>> fetchStages({String? portfolioId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/stages',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchStage(
    String slug, {
    String? portfolioId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/stages/$slug',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return res.data ?? const {};
  }

  /// Каталог концепций. Для пользователя возвращает уровень владения каждой.
  Future<List<Map<String, dynamic>>> fetchConcepts({String? portfolioId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/concepts',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Биография концепции в курсе: где введена, где углублена, где применяется.
  Future<Map<String, dynamic>> fetchConcept(
    String slug, {
    String? portfolioId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/concepts/$slug',
      queryParameters: {
        if (portfolioId != null) 'portfolioId': portfolioId,
      },
    );
    return res.data ?? const {};
  }

  /// Сообщает бэку о реальной торговой операции на учебном счёте, чтобы
  /// закрыть совпавшие требования практики этапа. Идемпотентно по
  /// [idempotencyKey] — повторный вызов с тем же ключом вернёт прошлый
  /// результат без повторного зачёта.
  Future<Map<String, dynamic>> postPracticeEvent({
    required String stageSlug,
    required String portfolioId,
    required String idempotencyKey,
    required String type,
    String? symbol,
    String? assetClass,
    num? qty,
    num? price,
    Map<String, dynamic>? payload,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/stages/$stageSlug/practice-events',
      queryParameters: {'portfolioId': portfolioId},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      data: {
        'idempotencyKey': idempotencyKey,
        'type': type,
        if (symbol != null) 'symbol': symbol,
        if (assetClass != null) 'assetClass': assetClass,
        if (qty != null) 'qty': qty,
        if (price != null) 'price': price,
        if (payload != null) 'payload': payload,
      },
    );
    return res.data ?? const {};
  }

  Future<List<Map<String, dynamic>>> fetchAchievements(String portfolioId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/me/achievements',
      queryParameters: {'portfolioId': portfolioId},
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }
}

final learningApiClientProvider = Provider<LearningApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return LearningApiClient(
    baseUrl: config.aloriaApiBaseUrl,
    enableLogging: config.enableLogging,
  );
});
