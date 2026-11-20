import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Backend address of the app. The default below is only used until someone changes it in the app:
/// Login screen -> "Server" button, or Admin -> Configuration -> Backend. The chosen address is
/// saved on the phone and survives restarts.
///
///  - Android emulator:        '10.0.2.2:8080'
///  - Real phone (same Wi-Fi): the IP of the computer running the backend, e.g. '192.168.1.5:8080'
class AppConfig {
  static const String defaultHost = '10.0.2.2:8080';
  static const String _key = 'backend_host';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _host = defaultHost;

  static String get host => _host;
  static String get apiBase => 'http://$_host/api';
  static String get wsUrl => 'ws://$_host/ws';

  /// Reads the saved address (call once at start, before any request).
  static Future<void> load() async {
    try {
      final n = normalize(await _storage.read(key: _key));
      if (n != null) _host = n;
    } catch (_) {}
  }

  /// [value] must come from [normalize].
  static Future<void> save(String value) async {
    _host = value;
    try {
      await _storage.write(key: _key, value: value);
    } catch (_) {}
  }

  static Future<void> reset() async {
    _host = defaultHost;
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }

  /// Cleans user input into "host:port". Accepts "192.168.0.117", "192.168.0.117:8080" and
  /// "http://192.168.0.117:8080/api". The port defaults to 8080. Returns null when invalid.
  static String? normalize(String? input) {
    if (input == null) return null;
    var s = input.trim().replaceFirst(RegExp(r'^(https?|wss?)://', caseSensitive: false), '');
    s = s.split('/').first.trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^([A-Za-z0-9]([A-Za-z0-9.\-]*[A-Za-z0-9])?)(:(\d{1,5}))?$').firstMatch(s);
    if (m == null) return null;
    final port = m.group(4);
    if (port == null) return '$s:8080';
    final p = int.parse(port);
    return (p >= 1 && p <= 65535) ? s : null;
  }
}
