import 'package:aloria/core/errors/error_types.dart';
import 'package:aloria/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthTokens> login({
    required String login,
    required String password,
    String? twoFactorPin,
  }) async {
    try {
      final res = await _dio.post(
        'https://lk.alor.ru/api/sso-auth/client',
        data: {
          'credentials': {
            'login': login,
            'password': password,
            'twoFactorPin': twoFactorPin,
          },
          'client_id': 'SingleSignOn',
          'redirect_url': '//astras.alor.ru/auth/callback/',
        },
        options: Options(headers: _defaultHeaders),
      );

      final data = res.data as Map<String, dynamic>;
      return AuthTokens.fromLogin(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final res = await _dio.post(
        'https://lk-api.alor.ru/auth/actions/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: _defaultHeaders),
      );
      final data = res.data as Map<String, dynamic>;
      return AuthTokens.fromRefresh(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}

const _defaultHeaders = <String, String>{
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-ALOR-ORIGINATOR': 'Astras',
};

AppError _mapError(DioException e) {
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return const AppError.network('timeout');
  }
  final status = e.response?.statusCode ?? 0;
  if (status >= 500) return AppError.server('server_$status');
  if (status == 401) return const AppError.unauthorized();
  return AppError.network(e.message ?? 'network_error');
}
