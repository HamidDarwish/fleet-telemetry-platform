import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config.dart';

/// WebSocket (STOMP) connection for live telemetry and alerts (FR-5.2, FR-8.3).
class LiveService {
  StompClient? _client;

  void connect({
    required void Function(Map<String, dynamic>) onTelemetry,
    required void Function(Map<String, dynamic>) onAlert,
    required void Function(bool) onStatus,
  }) {
    disconnect();
    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (StompFrame frame) {
          onStatus(true);
          _client?.subscribe(
            destination: '/topic/telemetry',
            callback: (f) {
              if (f.body != null) onTelemetry(jsonDecode(f.body!) as Map<String, dynamic>);
            },
          );
          _client?.subscribe(
            destination: '/topic/alerts',
            callback: (f) {
              if (f.body != null) onAlert(jsonDecode(f.body!) as Map<String, dynamic>);
            },
          );
        },
        onWebSocketError: (dynamic e) => onStatus(false),
        onStompError: (StompFrame f) => onStatus(false),
        onDisconnect: (StompFrame f) => onStatus(false),
      ),
    );
    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}
