enum AppEnv { dev, stage, prod }

class AppConfig {
  final AppEnv env;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final bool enableLogging;

  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
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
      defaultValue: 'https://api.alor.ru',
    );
    const wsUrl = String.fromEnvironment(
      'WS_BASE_URL',
      defaultValue: 'wss://api.alor.ru/ws',
    );
    const logging = bool.fromEnvironment('ENABLE_LOGGING', defaultValue: true);
    return AppConfig(
      env: env,
      apiBaseUrl: baseUrl,
      wsBaseUrl: wsUrl,
      enableLogging: logging,
    );
  }
}
