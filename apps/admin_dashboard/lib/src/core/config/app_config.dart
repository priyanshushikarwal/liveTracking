class AppConfig {
  const AppConfig._();

  static const appName = 'LiveTrack Admin Dashboard';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );
  static const websocketBaseUrl = String.fromEnvironment(
    'WEBSOCKET_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
}
