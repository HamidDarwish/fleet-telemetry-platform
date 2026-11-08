import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fleet_map.dart';
import '../widgets/state_views.dart';
import '../widgets/stat_card.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_widgets.dart';
import 'shell_scope.dart';

/// FR-5.5
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (state.loadError != null) ...[
              NoticeBanner(message: state.loadError!, onRetry: state.loadAll, retrying: state.loading),
              const SizedBox(height: 14),
            ],
            _StatsSection(state: state, nav: nav),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Live vehicle tracking',
              actionLabel: 'View full map',
              onAction: nav?.action(AppTab.map),
            ),
            _MapPreview(state: state, onOpen: nav?.action(AppTab.map)),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent alerts',
              actionLabel: 'View all',
              onAction: nav?.action(AppTab.alerts),
            ),
            _RecentAlerts(state: state),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Maintenance overview'),
            _MaintenanceOverview(state: state, nav: nav),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final AppState state;
  final ShellScope? nav;
  const _StatsSection({required this.state, required this.nav});

  @override
  Widget build(BuildContext context) {
    final d = state.dashboard;
    if (d == null) {
      if (state.loading) return const StatGridSkeleton();
      return const AppCard(
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: 'Fleet statistics unavailable',
          message: 'Pull down to refresh once the server is reachable.',
          compact: true,
        ),
      );
    }
    final openCritical = state.alerts.where((a) => !a.acknowledged && a.severity == 'CRITICAL').length;
    return StatGrid(
      children: [
        StatCard(
          icon: Icons.local_shipping_rounded,
          label: 'Total vehicles',
          value: '${d.totalVehicles}',
          color: AppColors.primary,
          caption: 'In your fleet',
          onTap: nav?.action(AppTab.vehicles),
        ),
        StatCard(
          icon: Icons.check_circle_rounded,
          label: 'Active vehicles',
          value: '${d.activeVehicles}',
          color: AppColors.success,
          caption: d.criticalVehicles > 0 ? '${d.criticalVehicles} critical' : 'No critical vehicles',
          captionColor: d.criticalVehicles > 0 ? AppColors.error : null,
          onTap: nav?.action(AppTab.vehicles),
        ),
        StatCard(
          icon: Icons.notifications_active_rounded,
          label: 'Open alerts',
          value: '${d.openAlerts}',
          color: d.openAlerts > 0 ? AppColors.warning : AppColors.success,
          caption: openCritical > 0 ? '$openCritical critical' : (d.openAlerts > 0 ? 'Need attention' : 'All clear'),
          captionColor: openCritical > 0 ? AppColors.error : null,
          onTap: nav?.action(AppTab.alerts),
        ),
        StatCard(
          icon: Icons.build_circle_rounded,
          label: 'Maintenance due',
          value: '${d.maintenanceDue}',
          color: d.maintenanceDue > 0 ? AppColors.orange : AppColors.success,
          caption: d.maintenanceDue > 0 ? 'Service required' : 'Nothing due',
          captionColor: d.maintenanceDue > 0 ? AppColors.orange : null,
        ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  final AppState state;
  final VoidCallback? onOpen;
  const _MapPreview({required this.state, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final positioned = state.vehicles.where((v) => v.hasPosition).toList();

    if (positioned.isEmpty) {
      if (state.loading) return const Skeleton(height: 220, radius: AppRadius.card);
      return AppCard(
        child: EmptyState(
          icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.location_searching_rounded,
          title: state.loadError != null ? 'Map unavailable' : 'No vehicle positions yet',
          message: state.loadError != null
              ? 'The server is unreachable, so vehicle locations cannot be shown.'
              : 'Locations appear here as soon as vehicles report telemetry.',
          actionLabel: state.loadError != null ? 'Retry' : null,
          onAction: state.loadError != null ? state.loadAll : null,
          color: state.loadError != null ? AppColors.error : null,
          compact: true,
        ),
      );
    }

    int count(String status) => positioned.where((v) => v.status == status).length;
    final live = state.liveStatus;
    final overlayColor = live == LiveStatus.connected
        ? AppColors.success
        : (live == LiveStatus.connecting ? AppColors.warning : AppColors.error);
    final overlayText = live == LiveStatus.connected
        ? 'Live'
        : (live == LiveStatus.connecting ? 'Connecting…' : 'Offline · last known positions');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card - 1)),
            child: SizedBox(
              height: 210,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: FleetMap(vehicles: positioned, interactive: false, compact: true)),
                  ),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(onTap: onOpen),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.surface.withAlpha(235),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: overlayColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(overlayText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                LegendItem(color: AppColors.success, label: 'Active', count: count('NORMAL')),
                LegendItem(color: AppColors.warning, label: 'Warning', count: count('WARNING')),
                LegendItem(color: AppColors.error, label: 'Critical', count: count('CRITICAL')),
                LegendItem(color: AppColors.offline, label: 'Offline', count: count('OFFLINE')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAlerts extends StatelessWidget {
  final AppState state;
  const _RecentAlerts({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.alerts.isEmpty) {
      if (state.loading) return const ListSkeleton(count: 2);
      return const AppCard(
        child: EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No alerts yet',
          message: 'New alerts show up here in real time.',
          compact: true,
        ),
      );
    }
    final recent = state.alerts.take(4).toList();
    return Column(
      children: [
        for (var i = 0; i < recent.length; i++) ...[
          AlertTile(alert: recent[i], compact: true),
          if (i < recent.length - 1) const SizedBox(height: 10),
        ],
      ],
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
                    child: Text('Service schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                (state.loading
                    ? const Column(children: [Skeleton(height: 12), SizedBox(height: 10), Skeleton(height: 12)])
                    : Text(
                        'No maintenance rules are available yet.',
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
                for (var i = 0; i < rules.length && i < 4; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  RuleTile(rule: rules[i], plate: plateOf(rules[i].vehicleId)),
                ],
                if (rules.length > 4) ...[
                  const SizedBox(height: 12),
                  Text('+ ${rules.length - 4} more rules',
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
              (openCount ?? 0) == 0 ? 'No open work orders.' : 'Open work orders awaiting service.',
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
