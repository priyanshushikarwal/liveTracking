class AppConfig {
  const AppConfig._();

  static const appName = 'LiveTrack Field Force';
  static const useDemoMode = bool.fromEnvironment(
    'USE_DEMO_MODE',
    defaultValue: false,
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );
  static const websocketBaseUrl = String.fromEnvironment(
    'WEBSOCKET_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
  static const attendanceAllowedRadii = [50, 100, 200];
  static const backgroundSyncIntervalMinutes = 3;
  static const defaultSiteLatitude = 28.4595;
  static const defaultSiteLongitude = 77.0266;
  static const defaultSiteName = 'DLF Site Office';
}
