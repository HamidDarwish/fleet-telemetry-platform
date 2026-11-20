import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fleet_map.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_health.dart';
import 'shell_scope.dart';
import 'vehicles_screen.dart';


/// FR-5.1 .. FR-5.3: live map that follows the app theme, with glowing status-colored markers.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  int? _selectedId;
  String? _status; // null = all
  bool _fitted = false;
  bool _expanded = false; // bottom card: small by default, opens on tap or swipe up

  @override
  void initState() {
    super.initState();
    // If positions already exist, the map opens fitted to them (see FleetMap).
    _fitted = context.read<AppState>().vehicles.any((v) => v.hasPosition);
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _fit(List<Vehicle> vehicles) {
    final points = [for (final v in vehicles) LatLng(v.lat!, v.lng!)];
    if (points.isEmpty) return;
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    // Keep the markers clear of the top controls and the bottom card (or the side card in landscape).
    final pad = landscape
        ? const EdgeInsets.fromLTRB(380, 70, 72, 40)
        : EdgeInsets.fromLTRB(48, mq.padding.top + 90, 72, mq.padding.bottom + 150);
    try {
      if (points.length == 1) {
        _map.move(points.first, 14);
      } else {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points,
          padding: pad,
          maxZoom: 16,
        ));
      }
    } catch (_) {
      // The map is not ready yet; the user can tap the "fit" button later.
    }
  }

  void _zoom(double delta) {
    try {
      final cam = _map.camera;
      _map.move(cam.center, math.max(3.0, math.min(18.0, cam.zoom + delta)));
    } catch (_) {}
  }

  void _select(Vehicle v, {required bool move}) {
    setState(() => _selectedId = v.id);
    if (move && v.hasPosition) {
      try {
        _map.move(LatLng(v.lat!, v.lng!), math.max(_map.camera.zoom, 14.0));
      } catch (_) {}
    }
  }

  void _openDetails(Vehicle v) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = AppPalette.of(context);
    final all = state.vehicles.where((v) => v.hasPosition).toList();
    final vehicles = all.where((v) => _status == null || v.status == _status).toList();

    if (!_fitted && all.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit(all);
      });
    }

    int count(String status) => all.where((v) => v.status == status).length;

    Vehicle? selected;
    for (final v in vehicles) {
      if (v.id == _selectedId) selected = v;
    }
    selected ??= vehicles.isEmpty ? null : vehicles.first;

    String? notice;
    Color noticeColor = AppColors.error;
    IconData noticeIcon = Icons.cloud_off_rounded;
    if (state.loadError != null) {
      notice = state.loadError;
    } else if (state.liveStatus == LiveStatus.offline) {
      notice = 'Live updates are offline. Showing last known positions.';
    } else if (state.liveStatus == LiveStatus.connecting) {
      notice = 'Connecting to live updates…';
      noticeColor = AppColors.warning;
      noticeIcon = Icons.sync_rounded;
    }

    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final top = mq.padding.top;
    final bottom = mq.padding.bottom; // in portrait this already includes the navigation bar
    final unread = state.alerts.where((a) => !a.acknowledged).length;
    final openAlerts = ShellScope.maybeOf(context)?.action(AppTab.alerts);

    final noticeWidget = notice == null
        ? null
        : NoticeBanner(
            message: notice,
            icon: noticeIcon,
            color: noticeColor,
            onRetry: noticeColor == AppColors.error ? state.loadAll : null,
            retrying: state.loading,
          );

    final dock = selected == null
        ? null
        : _SelectedDock(
            vehicle: selected,
            all: vehicles,
            issues: vehicleIssues(selected, state.alerts, state.rules),
            expanded: _expanded,
            maxHeight: mq.size.height * (landscape ? 0.8 : 0.6),
            onToggle: () => setState(() => _expanded = !_expanded),
            onPick: (v) => _select(v, move: true),
            onDetails: () => _openDetails(selected!),
          );

    final attribution = Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 4),
      child: Text(
        '© OpenStreetMap contributors · Esri',
        style: TextStyle(
          fontSize: 10,
          color: p.textSecondary,
          shadows: [Shadow(color: p.surface, blurRadius: 4)],
        ),
      ),
    );

    // The map fills the whole page. Everything else floats on top of it.
    return Stack(
      children: [
        Positioned.fill(
          child: FleetMap(
            vehicles: vehicles,
            controller: _map,
            selectedId: selected?.id,
            showAttribution: false,
            onVehicleTap: (v) => _select(v, move: false),
          ),
        ),
        if (all.isEmpty)
          Positioned.fill(
            child: Container(
              color: p.background.withAlpha(225),
              alignment: Alignment.center,
              child: state.loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Skeleton(height: 120, radius: AppRadius.card),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppCard(
                        child: EmptyState(
                          icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.location_searching_rounded,
                          title: state.loadError != null ? "Can't show the map" : 'No positions yet',
                          message: state.loadError != null
                              ? 'Vehicle locations cannot be loaded right now.'
                              : 'Vehicles appear on the map as soon as they send their first position.',
                          actionLabel: state.loadError != null ? 'Retry' : null,
                          onAction: state.loadError != null ? state.loadAll : null,
                          color: state.loadError != null ? AppColors.error : null,
                          compact: true,
                        ),
                      ),
                    ),
            ),
          )
        else if (vehicles.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text('No vehicles with this status', style: TextStyle(color: p.textSecondary, fontSize: 14)),
              ),
            ),
          ),
        // Top: status filters and the alerts bell.
        Positioned(
          top: top + 10,
          left: 12,
          right: 12,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _MapPill(label: 'All', count: all.length, selected: _status == null, onTap: () => setState(() => _status = null)),
                      for (final s in const ['NORMAL', 'WARNING', 'CRITICAL', 'OFFLINE']) ...[
                        const SizedBox(width: 8),
                        _MapPill(
                          label: s == 'NORMAL' ? 'Active' : pretty(s),
                          count: count(s),
                          color: statusColor(s),
                          selected: _status == s,
                          onTap: () => setState(() => _status = _status == s ? null : s),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (openAlerts != null) ...[
                const SizedBox(width: 10),
                _MapButton(icon: Icons.notifications_rounded, tooltip: 'Alerts', badge: unread, onTap: openAlerts),
              ],
            ],
          ),
        ),
        // Right side: fit and zoom.
        Positioned(
          top: top + 66,
          right: 12,
          child: Column(
            children: [
              _MapButton(icon: Icons.center_focus_strong_rounded, tooltip: 'Show all vehicles', onTap: vehicles.isEmpty ? null : () => _fit(vehicles)),
              const SizedBox(height: 10),
              _MapButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onTap: () => _zoom(1)),
              const SizedBox(height: 10),
              _MapButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onTap: () => _zoom(-1)),
            ],
          ),
        ),
        // Bottom: a notice, the map credit and the small vehicle card.
        if (landscape)
          Positioned(
            left: 12,
            bottom: math.max(bottom, 0) + 12,
            width: 344,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (noticeWidget != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: noticeWidget),
                if (dock != null) dock,
              ],
            ),
          )
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (noticeWidget != null)
                  Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: noticeWidget),
                attribution,
                if (dock != null)
                  Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 8), child: dock)
                else
                  SizedBox(height: bottom + 8),
              ],
            ),
          ),
        if (landscape)
          Positioned(right: 12, bottom: 6, child: attribution),
      ],
    );
  }
}

class _MapPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _MapPill({required this.label, required this.count, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final bg = selected ? (color ?? primary) : p.surface.withAlpha(240);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? Colors.transparent : p.border),
          boxShadow: selected
              ? [BoxShadow(color: (color ?? primary).withAlpha(110), blurRadius: 14, offset: const Offset(0, 4))]
              : const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null && !selected) ...[
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(color: selected ? Colors.white : p.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(
                    color: selected ? Colors.white.withAlpha(220) : p.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final int badge;
  const _MapButton({required this.icon, required this.tooltip, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final button = Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface.withAlpha(245),
        elevation: 3,
        shadowColor: const Color(0x330F172A),
        shape: CircleBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: onTap == null ? p.textMuted : p.textPrimary, size: 22),
          ),
        ),
      ),
    );
    if (badge <= 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -3,
          right: -3,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.surface, width: 1.5),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small card for the selected vehicle. Collapsed it is one row; tap or swipe up to see everything.
class _SelectedDock extends StatelessWidget {
  final Vehicle vehicle;
  final List<Vehicle> all;
  final List<VehicleIssue> issues;
  final bool expanded;
  final double maxHeight;
  final VoidCallback onToggle;
  final ValueChanged<Vehicle> onPick;
  final VoidCallback onDetails;

  const _SelectedDock({
    required this.vehicle,
    required this.all,
    required this.issues,
    required this.expanded,
    required this.maxHeight,
    required this.onToggle,
    required this.onPick,
    required this.onDetails,
  });

  Widget _tile(BuildContext context, IconData icon, String value, String label, {Color? tint}) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: tint ?? p.textPrimary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: p.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: p.textSecondary, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = vehicle;
    final color = statusColor(v.status);
    final fuelLow = v.fuel != null && v.fuel! < 30;
    final hot = v.temp != null && v.temp! >= 95;
    final summary = '${num0(v.speed)} km/h  ·  ${num0(v.fuel)}% fuel';
    final collapsedRow = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onVerticalDragEnd: (d) {
        final vy = d.primaryVelocity ?? 0;
        if ((vy < -150 && !expanded) || (vy > 150 && expanded)) onToggle();
      },
      child: Row(
        children: [
          SizedBox(width: 76, child: VehicleCarArt(vehicle: v, issues: issues, zones: false)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(v.plate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(width: 6),
            StatusChip(label: '${issues.length}', color: AppColors.warning),
          ],
          Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: p.textMuted),
        ],
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (all.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final x = all[i];
                final on = x.id == v.id;
                return GestureDetector(
                  onTap: () => onPick(x),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? primary : p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor(x.status), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(x.plate,
                            style: TextStyle(color: on ? Colors.white : p.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(v.model.isEmpty ? 'Unknown model' : v.model,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary, fontSize: 13)),
            ),
            StatusChip(label: pretty(v.status), color: color),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _tile(context, Icons.speed_rounded, '${num0(v.speed)} km/h', 'Speed'),
            const SizedBox(width: 8),
            _tile(context, Icons.local_gas_station_rounded, '${num0(v.fuel)}%', 'Fuel', tint: fuelLow ? AppColors.warning : null),
            const SizedBox(width: 8),
            _tile(context, Icons.thermostat_rounded, '${num0(v.temp)} °C', 'Engine', tint: hot ? AppColors.error : null),
            const SizedBox(width: 8),
            _tile(context, Icons.schedule_rounded, timeAgo(v.lastUpdate), 'Updated'),
          ],
        ),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 10),
          IssueChips(issues: issues),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onDetails,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open vehicle'),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x261E3A78), blurRadius: 24, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: expanded ? null : const NeverScrollableScrollPhysics(),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                collapsedRow,
                if (expanded) Padding(padding: const EdgeInsets.only(right: 4), child: details),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
