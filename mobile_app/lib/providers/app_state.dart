import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/live_service.dart';

/// Holds the session and all data shown in the app; live updates change it in place.
class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  final LiveService _live = LiveService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Session? session;
  bool initializing = true;
  bool liveConnected = false;
  String? loadError;

  List<Vehicle> vehicles = [];
  List<AlertItem> alerts = [];
  List<WorkOrder> workOrders = [];
  Dashboard? dashboard;

  Timer? _timer;
  final StreamController<AlertItem> _alertCtrl = StreamController<AlertItem>.broadcast();
  Stream<AlertItem> get alertStream => _alertCtrl.stream;

  // ---------- session ----------

  /// Called once at start: restores the saved login (FR-1.5).
  Future<void> restore() async {
    try {
      final saved = await _storage.read(key: 'session');
      if (saved != null) {
        session = Session.fromJson(jsonDecode(saved) as Map<String, dynamic>);
        api.token = session!.token;
        await loadAll();
        if (session != null) _startLive();
      }
    } catch (_) {
      session = null;
    }
    initializing = false;
    notifyListeners();
  }

  /// Returns null on success, otherwise an error message.
  Future<String?> login(String email, String password) async {
    try {
      final s = await api.login(email.trim(), password);
      session = s;
      api.token = s.token;
      await _storage.write(key: 'session', value: jsonEncode(s.toJson()));
      await loadAll();
      if (session != null) _startLive();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    _timer?.cancel();
    _live.disconnect();
    await _storage.delete(key: 'session');
    api.token = null;
    session = null;
    liveConnected = false;
    vehicles = [];
    alerts = [];
    workOrders = [];
    dashboard = null;
    notifyListeners();
  }

  // ---------- loading ----------

  Future<void> loadAll() async {
    final s = session;
    if (s == null) return;
    try {
      vehicles = await api.vehicles();
      alerts = await api.alerts();
      if (s.isAdmin || s.isManager) dashboard = await api.dashboard();
      if (s.isManager || s.isTechnician) workOrders = await api.workOrders();
      loadError = null;
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout();
        return;
      }
      loadError = e.message;
    }
    notifyListeners();
  }

  /// Light refresh of the numbers that change without a direct WebSocket message.
  Future<void> _refreshLight() async {
    final s = session;
    if (s == null) return;
    try {
      if (s.isAdmin || s.isManager) dashboard = await api.dashboard();
      if (s.isManager || s.isTechnician) workOrders = await api.workOrders();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401) await logout();
    }
  }

  // ---------- live ----------

  void _startLive() {
    _live.connect(
      onTelemetry: _onTelemetry,
      onAlert: _onAlert,
      onStatus: (connected) {
        liveConnected = connected;
        notifyListeners();
      },
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshLight());
  }

  void _onTelemetry(Map<String, dynamic> j) {
    final id = (j['vehicleId'] as num).toInt();
    final match = vehicles.where((v) => v.id == id);
    if (match.isEmpty) return; // a driver does not see other vehicles
    match.first.applyLive(j);
    notifyListeners();
  }

  void _onAlert(Map<String, dynamic> j) {
    final alert = AlertItem.fromJson(j);
    if (!_isRelevant(alert)) return; // FR-8.6
    alerts.insert(0, alert);
    if (alerts.length > 200) alerts.removeLast();
    _alertCtrl.add(alert);
    notifyListeners();
    _refreshLight(); // an alert may have created a work order
  }

  bool _isRelevant(AlertItem a) {
    final s = session;
    if (s == null) return false;
    if (s.isDriver) return vehicles.any((v) => v.id == a.vehicleId);
    if (s.isTechnician) return workOrders.any((w) => w.vehicleId == a.vehicleId);
    return true;
  }

  // ---------- actions ----------

  Future<void> acknowledge(AlertItem a) async {
    await api.acknowledgeAlert(a.id);
    a.acknowledged = true;
    notifyListeners();
  }

  Future<void> updateWorkOrder(int id, Map<String, dynamic> changes) async {
    await api.updateWorkOrder(id, changes);
    workOrders = await api.workOrders();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live.disconnect();
    _alertCtrl.close();
    super.dispose();
  }
}
