/// Build-time configuration.
///
/// Values are injected with `--dart-define` so no endpoint or credential is
/// baked into source:
///
/// ```
/// flutter run --dart-define=DRP_API_BASE_URL=http://192.168.1.20:8000/api/v1
/// ```
class AppConfig {
  const AppConfig._();

  /// 10.0.2.2 is the Android emulator's alias for the host machine's loopback.
  /// Use `http://127.0.0.1:8000/api/v1` on desktop and an actual LAN address on
  /// a physical handset.
  static const String apiBaseUrl = String.fromEnvironment(
    'DRP_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// A field device must never block on the network. Probes fail fast.
  static const Duration reachabilityTimeout = Duration(seconds: 3);

  /// Login is allowed to take longer than a reachability probe, but not much.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// How often connectivity is re-evaluated when nothing else changes.
  static const Duration connectivityRefreshInterval = Duration(seconds: 20);

  static const String localDatabaseName = 'drp_field';
}
