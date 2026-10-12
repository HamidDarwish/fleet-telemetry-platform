/// The ONLY place where the backend address is defined.
///
///  - Android emulator:      '10.0.2.2:8080'
///  - Real phone (same Wi-Fi): the IP address of the computer running the backend, e.g. '192.168.1.5:8080'
class AppConfig {
  static const String host = '10.0.2.2:8080';
  static const String apiBase = 'http://$host/api';
  static const String wsUrl = 'ws://$host/ws';
}
