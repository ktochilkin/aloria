import 'package:aloria/app_config.dart';
import 'package:aloria/core/errors/error_types.dart';
import 'package:aloria/features/auth/data/models/auth_tokens.dart';
import 'package:dio/dio.dart';

class AuthRepository {
  AuthRepository(this._dio, this._config);

  final Dio _dio;
  final AppConfig _config;

  Future<AuthTokens> login({
    required String login,
    required String password,
    String? twoFactorPin,
  }) async {
    try {
      final url = _buildUrl(_config.authBaseUrl, '/sso-auth/client');
      final res = await _dio.post(
        url,
        data: {
          'credentials': {
            'login': login,
            'password': password,
            'twoFactorPin': twoFactorPin,
          },
          'client_id': 'SingleSignOn',
          'redirect_url': _config.authRedirectUrl,
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
      final url = _buildUrl(_config.authApiBaseUrl, '/auth/actions/refresh');
      final res = await _dio.post(
        url,
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

String _buildUrl(String base, String path) {
  final normalizedBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return '$normalizedBase$normalizedPath';
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
