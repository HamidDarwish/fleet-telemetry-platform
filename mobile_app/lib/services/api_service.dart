import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});

  @override
  String toString() => message;
}

/// All REST calls to the Spring Boot backend. The app contains no business rules.
class ApiService {
  String? token;

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 10));
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 10));
          break;
        default:
          r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      }
    } on TimeoutException {
      throw ApiException('The server did not respond. Is the backend running?');
    } catch (_) {
      throw ApiException('Cannot reach the server (${AppConfig.host}). Check the address and the network.');
    }

    if (r.statusCode == 401 && token != null) {
      throw ApiException('Session expired. Please log in again.', status: 401);
    }
    final text = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 400) {
      var msg = 'Request failed (${r.statusCode})';
      try {
        final j = jsonDecode(text);
        if (j is Map && j['message'] != null) msg = j['message'].toString();
      } catch (_) {}
      throw ApiException(msg, status: r.statusCode);
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  Future<Session> login(String email, String password) async {
    final j = await _send('POST', '/auth/login', body: {'email': email, 'password': password});
    return Session(
      token: j['token'] as String,
      userId: (j['userId'] as num).toInt(),
      name: (j['name'] ?? '') as String,
      role: (j['role'] ?? '') as String,
    );
  }

  Future<List<Vehicle>> vehicles() async {
    final j = await _send('GET', '/vehicles') as List;
    return j.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Dashboard> dashboard() async =>
      Dashboard.fromJson(await _send('GET', '/dashboard') as Map<String, dynamic>);

  Future<List<AlertItem>> alerts() async {
    final j = await _send('GET', '/alerts') as List;
    return j.map((e) => AlertItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acknowledgeAlert(int id) => _send('PUT', '/alerts/$id/ack');

  Future<List<WorkOrder>> workOrders() async {
    final j = await _send('GET', '/work-orders') as List;
    return j.map((e) => WorkOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateWorkOrder(int id, Map<String, dynamic> changes) =>
      _send('PUT', '/work-orders/$id', body: changes);

  Future<List<TechnicianInfo>> technicians() async {
    final j = await _send('GET', '/work-orders/technicians') as List;
    return j.map((e) => TechnicianInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RuleView>> rules(int vehicleId) async {
    final j = await _send('GET', '/maintenance-rules?vehicleId=$vehicleId') as List;
    return j.map((e) => RuleView.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> simulatorStatus() async =>
      (await _send('GET', '/simulator/status')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> simulatorStart() async =>
      (await _send('POST', '/simulator/start')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> simulatorStop() async =>
      (await _send('POST', '/simulator/stop')) as Map<String, dynamic>;
}
