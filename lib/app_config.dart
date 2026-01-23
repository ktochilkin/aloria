enum AppEnv { dev, stage, prod }

class AppConfig {
  final AppEnv env;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String authBaseUrl;
  final String authApiBaseUrl;
  final String authRedirectUrl;
  final bool enableLogging;

  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.authBaseUrl,
    required this.authApiBaseUrl,
    required this.authRedirectUrl,
    required this.enableLogging,
  });

  factory AppConfig.fromEnv() {
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    final env = AppEnv.values.firstWhere(
      (e) => e.name == envStr,
      orElse: () => AppEnv.dev,
    );
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.alor.dev',
    );
    const wsUrl = String.fromEnvironment(
      'WS_BASE_URL',
      defaultValue: 'wss://api.alor.dev/ws',
    );
    const authBaseUrl = String.fromEnvironment(
      'AUTH_BASE_URL',
      defaultValue: 'https://lk-api.alor.dev',
    );
    const authApiBaseUrl = String.fromEnvironment(
      'AUTH_API_BASE_URL',
      defaultValue: 'https://lk-api.alor.dev',
    );
    const authRedirectUrl = String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: '//astras.alor.dev/auth/callback/',
    );
    const logging = bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);
    return AppConfig(
      env: env,
      apiBaseUrl: baseUrl,
      wsBaseUrl: wsUrl,
      authBaseUrl: authBaseUrl,
      authApiBaseUrl: authApiBaseUrl,
      authRedirectUrl: authRedirectUrl,
      enableLogging: logging,
    );
  }
}
