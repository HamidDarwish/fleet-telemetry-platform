import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../config.dart';
import '../services/live_service.dart';

/// State of the live (WebSocket) connection shown in the header.
enum LiveStatus { connecting, connected, offline }

/// Holds the session and all data shown in the app; live updates change it in place.
class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  final LiveService _live = LiveService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Session? session;
  bool initializing = true;
  bool liveConnected = false;
  LiveStatus liveStatus = LiveStatus.connecting;
  bool loading = false;
  String? loadError;
  ThemeMode themeMode = ThemeMode.light;

  List<Vehicle> vehicles = [];
  List<AlertItem> alerts = [];
  List<WorkOrder> workOrders = [];
  List<RuleView> rules = [];
  Dashboard? dashboard;

  Timer? _timer;
  Timer? _notifyTimer;
  Timer? _refreshDebounce;
  bool _notifyPending = false;
  final StreamController<AlertItem> _alertCtrl = StreamController<AlertItem>.broadcast();
  Stream<AlertItem> get alertStream => _alertCtrl.stream;

  // ---------- session ----------

  /// Called once at start: restores the saved login (FR-1.5).
  Future<void> restore() async {
    await AppConfig.load();   // the saved backend address must be known before the first request
    try {
      final t = await _storage.read(key: 'theme_mode');
      if (t != null) {
        themeMode = ThemeMode.values.firstWhere((m) => m.name == t, orElse: () => ThemeMode.light);
      }
    } catch (_) {}
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
    liveStatus = LiveStatus.connecting;
    loading = false;
    loadError = null;
    vehicles = [];
    alerts = [];
    workOrders = [];
    rules = [];
    dashboard = null;
    notifyListeners();
  }

  /// Saves a new backend address and reconnects (data and live updates) when someone is logged in.
  Future<void> applyServer(String host) async {
    await AppConfig.save(host);
    liveStatus = LiveStatus.connecting;
    notifyListeners();
    if (session != null) {
      await loadAll();
      if (session != null) _startLive();
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      await _storage.write(key: 'theme_mode', value: mode.name);
    } catch (_) {}
  }

  // ---------- loading ----------

  Future<void> loadAll() async {
    final s = session;
    if (s == null) return;
    loading = true;
    notifyListeners();
    try {
      vehicles = await api.vehicles();
      alerts = await api.alerts();
      if (s.isAdmin || s.isManager) {
        dashboard = await api.dashboard();
        await _loadRules();
      }
      if (s.isManager || s.isTechnician) workOrders = await api.workOrders();
      loadError = null;
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout();
        return;
      }
      loadError = e.message;
    } catch (_) {
      loadError = 'The server sent data the app could not read.';
    }
    loading = false;
    notifyListeners();
  }

  /// Maintenance rules only enrich the dashboard, so a failure here must not hide the rest.
  Future<void> _loadRules() async {
    try {
      rules = await api.rulesAll();
    } on ApiException catch (e) {
      if (e.status == 401) rethrow;
    }
  }

  /// Light refresh of the numbers that change without a direct WebSocket message.
  Future<void> _refreshLight() async {
    final s = session;
    if (s == null) return;
    try {
      if (s.isAdmin || s.isManager) {
        dashboard = await api.dashboard();
        await _loadRules();
      }
      if (s.isManager || s.isTechnician) workOrders = await api.workOrders();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401) await logout();
    }
  }

  // ---------- live ----------

  void _startLive() {
    liveStatus = LiveStatus.connecting;
    _live.connect(
      onTelemetry: _onTelemetry,
      onAlert: _onAlert,
      onStatus: (connected) {
        liveConnected = connected;
        liveStatus = connected ? LiveStatus.connected : LiveStatus.offline;
        notifyListeners();
      },
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshLight());
  }

  /// Live messages can arrive many times per second. Rebuilding every screen for each one makes the
  /// app lag, so they are merged into at most one rebuild per 800 ms.
  void _notifySoon() {
    if (_notifyTimer != null) {
      _notifyPending = true;
      return;
    }
    notifyListeners();
    _notifyTimer = Timer(const Duration(milliseconds: 800), () {
      _notifyTimer = null;
      if (_notifyPending) {
        _notifyPending = false;
        _notifySoon();
      }
    });
  }

  void _onTelemetry(Map<String, dynamic> j) {
    final id = (j['vehicleId'] as num).toInt();
    final match = vehicles.where((v) => v.id == id);
    if (match.isEmpty) return; // a driver does not see other vehicles
    match.first.applyLive(j);
    _notifySoon();
  }

  void _onAlert(Map<String, dynamic> j) {
    final alert = AlertItem.fromJson(j);
    if (!_isRelevant(alert)) return; // FR-8.6
    alerts.insert(0, alert);
    if (alerts.length > 200) alerts.removeLast();
    _alertCtrl.add(alert);
    _notifySoon();
    // An alert may have created a work order; many alerts in a row cause only one refresh.
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 3), _refreshLight);
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
    _notifyTimer?.cancel();
    _refreshDebounce?.cancel();
    _live.disconnect();
    _alertCtrl.close();
    super.dispose();
  }
}
