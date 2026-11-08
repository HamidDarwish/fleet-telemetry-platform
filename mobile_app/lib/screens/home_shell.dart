import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/theme_selector.dart';
import '../widgets/ui.dart';
import 'admin_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'shell_scope.dart';
import 'vehicles_screen.dart';
import 'work_orders_screen.dart';

class _TabInfo {
  final AppTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const _TabInfo(this.tab, this.label, this.icon, this.selectedIcon, this.page);
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
    final session = context.read<AppState>().session;
    final canView = session != null && _tabs(session).any((t) => t.tab == AppTab.alerts);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: a.severity == 'CRITICAL' ? AppColors.error : const Color(0xFFB45309),
      content: Row(
        children: [
          Icon(severityIcon(a.severity), color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      action: canView ? SnackBarAction(label: 'View', textColor: Colors.white, onPressed: () => _goTo(AppTab.alerts)) : null,
      duration: const Duration(seconds: 4),
    ));
  }

  List<_TabInfo> _tabs(Session s) {
    const dashboard = _TabInfo(AppTab.dashboard, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded, DashboardScreen());
    const map = _TabInfo(AppTab.map, 'Map', Icons.map_outlined, Icons.map_rounded, MapScreen());
    const vehicles =
        _TabInfo(AppTab.vehicles, 'Vehicles', Icons.directions_car_outlined, Icons.directions_car_rounded, VehiclesScreen());
    const alerts =
        _TabInfo(AppTab.alerts, 'Alerts', Icons.notifications_outlined, Icons.notifications_rounded, AlertsScreen());
    const orders = _TabInfo(AppTab.orders, 'Orders', Icons.build_circle_outlined, Icons.build_circle_rounded, WorkOrdersScreen());
    const admin =
        _TabInfo(AppTab.admin, 'Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded, AdminScreen());
    if (s.isAdmin) return [dashboard, map, vehicles, alerts, admin];
    if (s.isManager) return [dashboard, map, vehicles, alerts, orders];
    if (s.isTechnician) return [orders, alerts];
    return [map, vehicles, alerts]; // driver
  }

  void _goTo(AppTab tab) {
    final session = context.read<AppState>().session;
    if (session == null) return;
    final i = _tabs(session).indexWhere((t) => t.tab == tab);
    if (i >= 0 && i != _index) setState(() => _index = i);
  }

  ({String title, String subtitle}) _headline(AppTab tab, AppState state, int unread) {
    final moving = state.vehicles.where((v) => v.hasPosition).length;
    switch (tab) {
      case AppTab.dashboard:
        final d = state.dashboard;
        return (
          title: 'Fleet Overview',
          subtitle: d == null ? 'Live fleet monitoring' : '${d.totalVehicles} vehicles · ${d.activeVehicles} active',
        );
      case AppTab.map:
        return (title: 'Live Map', subtitle: '$moving vehicles reporting');
      case AppTab.vehicles:
        return (title: 'Vehicles', subtitle: '${state.vehicles.length} in your fleet');
      case AppTab.alerts:
        return (title: 'Alerts', subtitle: unread == 0 ? 'Everything acknowledged' : '$unread unacknowledged');
      case AppTab.orders:
        final open = state.workOrders.where((w) => w.status == 'OPEN' || w.status == 'IN_PROGRESS').length;
        return (title: 'Work Orders', subtitle: '$open open');
      case AppTab.admin:
        return (title: 'Administration', subtitle: 'Users, simulator and system');
    }
  }

  void _showProfile(Session session) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _ProfileSheet(session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.session!;
    final tabs = _tabs(session);
    final index = _index < tabs.length ? _index : 0;
    final unread = state.alerts.where((a) => !a.acknowledged).length;
    final p = AppPalette.of(context);
    final head = _headline(tabs[index].tab, state, unread);
    final hasAlertsTab = tabs.any((t) => t.tab == AppTab.alerts);

    return ShellScope(
      goTo: _goTo,
      available: {for (final t in tabs) t.tab},
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                title: head.title,
                subtitle: head.subtitle,
                status: state.liveStatus,
                unread: unread,
                name: session.name,
                onBell: hasAlertsTab ? () => _goTo(AppTab.alerts) : null,
                onProfile: () => _showProfile(session),
              ),
              Expanded(
                child: IndexedStack(index: index, children: tabs.map((t) => t.page).toList()),
              ),
            ],
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: _navIcon(t, t.icon, unread),
                  selectedIcon: _navIcon(t, t.selectedIcon, unread),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(_TabInfo t, IconData icon, int unread) {
    if (t.tab == AppTab.alerts && unread > 0) {
      return Badge(label: Text(unread > 99 ? '99+' : '$unread'), child: Icon(icon));
    }
    return Icon(icon);
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final LiveStatus status;
  final int unread;
  final String name;
  final VoidCallback? onBell;
  final VoidCallback onProfile;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.unread,
    required this.name,
    required this.onBell,
    required this.onProfile,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ConnectionPill(status: status),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onBell != null)
            CircleIconButton(
              tooltip: 'Alerts',
              onTap: onBell,
              child: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: Icon(Icons.notifications_none_rounded, size: 22, color: p.textPrimary),
              ),
            ),
          const SizedBox(width: 8),
          CircleIconButton(
            tooltip: 'Profile and settings',
            onTap: onProfile,
            child: Text(_initials,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  final Session session;
  const _ProfileSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.person_rounded, color: Theme.of(context).colorScheme.primary, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.name.isEmpty ? 'Signed in' : session.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    StatusChip(label: pretty(session.role), color: AppColors.primary, dot: false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary)),
          const SizedBox(height: 8),
          const ThemeSelector(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.read<AppState>().logout();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error.withAlpha(110)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
