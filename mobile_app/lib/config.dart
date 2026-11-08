/// The ONLY place where the backend address is defined.
///
/// Use the default for Android emulator:
///   flutter run --dart-define=API_HOST=10.0.2.2:8080
///
/// Use a LAN IP for a real phone on the same Wi‑Fi:
///   flutter run --dart-define=API_HOST=192.168.1.25:8080
class AppConfig {
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '192.168.137.170:8080',
  );

  static const String apiBase = 'http://$host/api';
  static const String wsUrl = 'ws://$host/ws';
}
