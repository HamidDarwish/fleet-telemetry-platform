import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'vehicles_screen.dart';
import 'work_orders_screen.dart';

class _TabInfo {
  final String label;
  final IconData icon;
  final Widget page;
  const _TabInfo(this.label, this.icon, this.page);
}

/// Bottom navigation with screens that depend on the role (FR-1.6).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription<AlertItem>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = context.read<AppState>().alertStream.listen(_onNewAlert);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// In-app notification for new important alerts (FR-8.3).
  void _onNewAlert(AlertItem a) {
    if (!mounted || a.severity == 'INFO') return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: severityColor(a.severity),
      content: Text(a.message),
      duration: const Duration(seconds: 4),
    ));
  }

  List<_TabInfo> _tabs(Session s) {
    const dashboard = _TabInfo('Dashboard', Icons.dashboard, DashboardScreen());
    const map = _TabInfo('Map', Icons.map, MapScreen());
    const vehicles = _TabInfo('Vehicles', Icons.directions_car, VehiclesScreen());
    const alerts = _TabInfo('Alerts', Icons.notifications, AlertsScreen());
    const orders = _TabInfo('Work orders', Icons.build, WorkOrdersScreen());
    const admin = _TabInfo('Admin', Icons.settings, AdminScreen());
    if (s.isAdmin) return [dashboard, map, vehicles, alerts, admin];
    if (s.isManager) return [dashboard, map, vehicles, alerts, orders];
    if (s.isTechnician) return [orders, alerts];
    return [map, vehicles, alerts]; // driver
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session!;
    final tabs = _tabs(session);
    final index = _index < tabs.length ? _index : 0;
    final unread = state.alerts.where((a) => !a.acknowledged).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[index].label),
        actions: [
          Tooltip(
            message: state.liveConnected ? 'Live connection active' : 'Live connection lost',
            child: Icon(state.liveConnected ? Icons.wifi : Icons.wifi_off,
                color: state.liveConnected ? Colors.green : Colors.red),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') context.read<AppState>().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text('${session.name} (${session.role})')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: tabs.map((t) => t.page).toList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: t.label == 'Alerts' && unread > 0
                  ? Badge(label: Text('$unread'), child: Icon(t.icon))
                  : Icon(t.icon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
