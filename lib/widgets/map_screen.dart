import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../screens/vehicles_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fleet_map.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_health.dart';


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
    try {
      if (points.length == 1) {
        _map.move(points.first, 14);
      } else {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(56, 120, 56, 56),
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

    return Column(
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: NoticeBanner(
              message: notice,
              icon: noticeIcon,
              color: noticeColor,
              onRetry: noticeColor == AppColors.error ? state.loadAll : null,
              retrying: state.loading,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: FleetMap(
                  vehicles: vehicles,
                  controller: _map,
                  selectedId: selected?.id,
                  onVehicleTap: (v) => _select(v, move: false),
                ),
              ),
              Positioned(
                top: 12,
                left: 0,
                right: 64,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
              Positioned(
                top: 64,
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
            ],
          ),
        ),
        if (selected != null)
          _SelectedSheet(
            vehicle: selected,
            all: vehicles,
            issues: vehicleIssues(selected, state.alerts, state.rules),
            onPick: (v) => _select(v, move: true),
            onDetails: () => _openDetails(selected!),
          ),
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
  const _MapButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Tooltip(
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
            width: 46,
            height: 46,
            child: Icon(icon, color: onTap == null ? p.textMuted : p.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for the selected vehicle: picture, status, live values and problems.
class _SelectedSheet extends StatelessWidget {
  final Vehicle vehicle;
  final List<Vehicle> all;
  final List<VehicleIssue> issues;
  final ValueChanged<Vehicle> onPick;
  final VoidCallback onDetails;

  const _SelectedSheet({
    required this.vehicle,
    required this.all,
    required this.issues,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: isDark ? null : const [BoxShadow(color: Color(0x1F1E3A78), blurRadius: 24, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          if (all.length > 1) ...[
            const SizedBox(height: 10),
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
                              style: TextStyle(
                                  color: on ? Colors.white : p.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                SizedBox(width: 118, child: VehicleCarArt(vehicle: v, issues: issues, zones: false)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.plate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 1),
                      Text(v.model.isEmpty ? 'Unknown model' : v.model,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(label: pretty(v.status), color: color),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
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
        ],
      ),
    );
  }
}
