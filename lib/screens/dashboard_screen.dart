import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fleet_map.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_health.dart';
import '../widgets/vehicle_widgets.dart';
import 'shell_scope.dart';
import 'vehicles_screen.dart';

/// FR-5.5: fleet status first, then the numbers, the live map and what needs attention.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nav = ShellScope.maybeOf(context);

    return RefreshIndicator(
      onRefresh: state.loadAll,
      child: ResponsiveBody(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (state.loadError != null) ...[
              NoticeBanner(message: state.loadError!, onRetry: state.loadAll, retrying: state.loading),
              const SizedBox(height: 12),
            ],
            _FleetStatusCard(state: state),
            const SizedBox(height: 12),
            _KpiGrid(state: state, nav: nav),
            const SizedBox(height: 24),
            SectionHeader(title: 'Live map', actionLabel: 'Open map', onAction: nav?.action(AppTab.map)),
            RepaintBoundary(child: _MapPreview(state: state, onOpen: nav?.action(AppTab.map))),
            const SizedBox(height: 24),
            SectionHeader(title: 'Needs attention', actionLabel: 'All alerts', onAction: nav?.action(AppTab.alerts)),
            _AttentionList(state: state),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Service and work orders'),
            _MaintenanceOverview(state: state, nav: nav),
          ],
        ),
      ),
    );
  }
}

String _compact(int? n) {
  if (n == null) return '–';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}k';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

/// Overall picture of the fleet: status bar, legend and three live numbers.
class _FleetStatusCard extends StatelessWidget {
  final AppState state;
  const _FleetStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final vs = state.vehicles;
    if (vs.isEmpty) {
      if (state.loading) return const Skeleton(height: 168, radius: AppRadius.card);
      return const AppCard(
        child: EmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'No vehicles yet',
          message: 'Vehicles assigned to you will show up here.',
          compact: true,
        ),
      );
    }
    int count(String s) => vs.where((v) => v.status == s).length;
    final normal = count('NORMAL');
    final warning = count('WARNING');
    final critical = count('CRITICAL');
    final offline = count('OFFLINE');
    final moving = vs.where((v) => (v.speed ?? 0) > 5).length;
    final fuels = [for (final v in vs) if (v.fuel != null) v.fuel!];
    final avgFuel = fuels.isEmpty ? null : fuels.reduce((a, b) => a + b) / fuels.length;
    final openCritical = state.alerts.where((a) => !a.acknowledged && a.severity == 'CRITICAL').length;

    final headline = critical > 0
        ? '$critical ${critical == 1 ? 'vehicle needs' : 'vehicles need'} urgent attention'
        : (warning > 0
            ? '$warning ${warning == 1 ? 'vehicle has' : 'vehicles have'} a warning'
            : 'Your fleet is running well');
    final headColor = critical > 0 ? AppColors.error : (warning > 0 ? AppColors.warning : AppColors.success);

    Widget seg(int n, Color c) => n == 0 ? const SizedBox.shrink() : Expanded(flex: n, child: Container(color: c));

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: headColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Text('${vs.length} total', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  seg(normal, AppColors.success),
                  seg(warning, AppColors.warning),
                  seg(critical, AppColors.error),
                  seg(offline, AppColors.offline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              LegendItem(color: AppColors.success, label: 'Active', count: normal),
              LegendItem(color: AppColors.warning, label: 'Warning', count: warning),
              LegendItem(color: AppColors.error, label: 'Critical', count: critical),
              LegendItem(color: AppColors.offline, label: 'Offline', count: offline),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: p.border),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(icon: Icons.speed_rounded, value: '$moving', label: 'Moving now'),
              _MiniStat(
                  icon: Icons.local_gas_station_rounded,
                  value: avgFuel == null ? '–' : '${avgFuel.toStringAsFixed(0)}%',
                  label: 'Average fuel'),
              _MiniStat(
                icon: Icons.priority_high_rounded,
                value: '$openCritical',
                label: 'Critical alerts',
                color: openCritical > 0 ? AppColors.error : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  const _MiniStat({required this.icon, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? p.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: color == null ? p.textPrimary : readableOn(context, color!))),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Four main numbers as a 2x2 grid of tappable tiles.
class _KpiGrid extends StatelessWidget {
  final AppState state;
  final ShellScope? nav;
  const _KpiGrid({required this.state, required this.nav});

  @override
  Widget build(BuildContext context) {
    final d = state.dashboard;
    final openCritical = state.alerts.any((a) => !a.acknowledged && a.severity == 'CRITICAL');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Kpi(
                icon: Icons.local_shipping_rounded,
                label: 'Vehicles',
                value: _compact(d?.totalVehicles),
                color: AppColors.primary,
                onTap: nav?.action(AppTab.vehicles),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Kpi(
                icon: Icons.check_circle_rounded,
                label: 'Active now',
                value: _compact(d?.activeVehicles),
                color: AppColors.success,
                onTap: nav?.action(AppTab.vehicles),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                icon: Icons.notifications_active_rounded,
                label: 'Open alerts',
                value: _compact(d?.openAlerts),
                color: openCritical ? AppColors.error : AppColors.warning,
                onTap: nav?.action(AppTab.alerts),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Kpi(
                icon: Icons.build_rounded,
                label: 'Service due',
                value: _compact(d?.maintenanceDue),
                color: AppColors.orange,
                onTap: nav?.action(AppTab.orders),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _Kpi({required this.icon, required this.label, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)),
                ),
                const SizedBox(height: 2),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live map preview. Tapping it opens the full map.
class _MapPreview extends StatelessWidget {
  final AppState state;
  final VoidCallback? onOpen;
  const _MapPreview({required this.state, required this.onOpen});

  static const double _height = 250;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final positioned = state.vehicles.where((v) => v.hasPosition).toList();

    if (positioned.isEmpty) {
      if (state.loading) return const Skeleton(height: _height, radius: AppRadius.card);
      return AppCard(
        child: EmptyState(
          icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.location_searching_rounded,
          title: state.loadError != null ? "Can't show the map" : 'No positions yet',
          message: state.loadError != null
              ? 'The server is unreachable, so vehicle locations cannot be shown.'
              : 'Vehicles show up on the map as soon as they send their first position.',
          actionLabel: state.loadError != null ? 'Retry' : null,
          onAction: state.loadError != null ? state.loadAll : null,
          color: state.loadError != null ? AppColors.error : null,
          compact: true,
        ),
      );
    }

    final live = state.liveStatus;
    final overlayColor = live == LiveStatus.connected
        ? AppColors.success
        : (live == LiveStatus.connecting ? AppColors.warning : AppColors.error);
    final overlayText = live == LiveStatus.connected
        ? 'Live'
        : (live == LiveStatus.connecting ? 'Connecting…' : 'Offline · last known positions');

    Widget pill({required Widget child}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: p.surface.withAlpha(238),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: p.border),
          ),
          child: child,
        );

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card - 1),
        child: SizedBox(
          height: _height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(child: FleetMap(vehicles: positioned, interactive: false, compact: true)),
              ),
              Positioned.fill(
                child: Material(type: MaterialType.transparency, child: InkWell(onTap: onOpen)),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IgnorePointer(
                  child: pill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: overlayColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(overlayText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: pill(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${positioned.length} on the map',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 16, color: p.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vehicles that need a look, worst first. Built from real telemetry, alerts and service rules.
class _AttentionList extends StatelessWidget {
  final AppState state;
  const _AttentionList({required this.state});

  static int _rank(String l) => l == 'CRITICAL' ? 0 : (l == 'WARNING' ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (state.vehicles.isEmpty && state.loading) return const ListSkeleton(count: 2);

    final rows = <(Vehicle, List<VehicleIssue>)>[];
    for (final v in state.vehicles) {
      final issues = vehicleIssues(v, state.alerts, state.rules).where((i) => i.level != 'INFO').toList();
      if (issues.isNotEmpty) rows.add((v, issues));
    }
    rows.sort((a, b) => _rank(a.$2.first.level).compareTo(_rank(b.$2.first.level)));

    if (rows.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'All quiet for now',
          message: "No vehicle needs attention. When something comes up, you'll see it here right away.",
          compact: true,
        ),
      );
    }

    final shown = rows.take(4).toList();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.border),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: shown[i].$1.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    IconBadge(icon: shown[i].$2.first.icon, color: shown[i].$2.first.color, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shown[i].$1.plate,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(
                            shown[i].$2.first.title + (shown[i].$2.length > 1 ? '  +${shown[i].$2.length - 1} more' : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.textMuted),
                  ],
                ),
              ),
            ),
          ],
          if (rows.length > shown.length) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('+ ${rows.length - shown.length} more vehicles need a look',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaintenanceOverview extends StatelessWidget {
  final AppState state;
  final ShellScope? nav;
  const _MaintenanceOverview({required this.state, required this.nav});

  static int _rank(String status) => status == 'DUE' ? 0 : (status == 'DUE_SOON' ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = state.dashboard;
    final rules = [...state.rules]..sort((a, b) {
        final r = _rank(a.status).compareTo(_rank(b.status));
        return r != 0 ? r : b.percentUsed.compareTo(a.percentUsed);
      });
    final overdue = rules.where((r) => r.status == 'DUE').length;
    final dueSoon = rules.where((r) => r.status == 'DUE_SOON').length;
    final upcoming = rules.length - overdue - dueSoon;
    String plateOf(int vehicleId) {
      for (final v in state.vehicles) {
        if (v.id == vehicleId) return v.plate;
      }
      return '';
    }

    return Column(
      children: [
        _WorkOrderSummary(state: state, openCount: d?.openWorkOrders, onTap: nav?.action(AppTab.orders)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.event_repeat_rounded, color: AppColors.orange, size: 36),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Coming up for service', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                (state.loading
                    ? const Column(children: [Skeleton(height: 12), SizedBox(height: 10), Skeleton(height: 12)])
                    : Text(
                        'No service schedules have been set up yet.',
                        style: TextStyle(fontSize: 13, color: p.textSecondary),
                      ))
              else ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    LegendItem(color: AppColors.error, label: 'Overdue', count: overdue),
                    LegendItem(color: AppColors.warning, label: 'Due soon', count: dueSoon),
                    LegendItem(color: AppColors.success, label: 'Upcoming', count: upcoming),
                  ],
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < rules.length && i < 3; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  RuleTile(rule: rules[i], plate: plateOf(rules[i].vehicleId)),
                ],
                if (rules.length > 3) ...[
                  const SizedBox(height: 12),
                  Text('+ ${rules.length - 3} more rules',
                      style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkOrderSummary extends StatelessWidget {
  final AppState state;
  final int? openCount;
  final VoidCallback? onTap;
  const _WorkOrderSummary({required this.state, required this.openCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final List<WorkOrder> orders = state.workOrders;
    final open = orders.where((w) => w.status == 'OPEN').length;
    final progress = orders.where((w) => w.status == 'IN_PROGRESS').length;
    final done = orders.where((w) => w.status == 'COMPLETED').length;
    final total = open + progress + done;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.assignment_rounded, color: AppColors.primary, size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Work orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              if (openCount != null)
                Text('$openCount open', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: p.textMuted),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (open > 0) Expanded(flex: open, child: Container(color: AppColors.primary)),
                    if (progress > 0) Expanded(flex: progress, child: Container(color: AppColors.warning)),
                    if (done > 0) Expanded(flex: done, child: Container(color: AppColors.success)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                LegendItem(color: AppColors.primary, label: 'Open', count: open),
                LegendItem(color: AppColors.warning, label: 'In progress', count: progress),
                LegendItem(color: AppColors.success, label: 'Completed', count: done),
              ],
            ),
          ] else if (state.loading && openCount == null) ...[
            const SizedBox(height: 14),
            const Skeleton(height: 8),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              (openCount ?? 0) == 0 ? 'Nothing is waiting for the workshop.' : 'Jobs are waiting for the workshop.',
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
