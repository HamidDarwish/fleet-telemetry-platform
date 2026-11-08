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
import 'vehicles_screen.dart';

/// FR-5.1 .. FR-5.3: live map with status-colored markers (OpenStreetMap tiles).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _cardWidth = 264;
  static const double _cardGap = 10;

  final MapController _map = MapController();
  final ScrollController _strip = ScrollController();
  int? _selectedId;
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
    _strip.dispose();
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
          padding: const EdgeInsets.all(56),
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

  void _select(Vehicle v, List<Vehicle> list, {required bool fromMap}) {
    setState(() => _selectedId = v.id);
    final i = list.indexWhere((x) => x.id == v.id);
    if (fromMap) {
      if (i >= 0 && _strip.hasClients) {
        final target = math.min(i * (_cardWidth + _cardGap), _strip.position.maxScrollExtent);
        _strip.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else if (v.hasPosition) {
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
    final vehicles = state.vehicles.where((v) => v.hasPosition).toList();

    if (!_fitted && vehicles.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit(vehicles);
      });
    }

    int count(String status) => vehicles.where((v) => v.status == status).length;

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
                  selectedId: _selectedId,
                  onVehicleTap: (v) => _select(v, vehicles, fromMap: true),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LegendItem(color: AppColors.success, label: 'Active', count: count('NORMAL')),
                      const SizedBox(height: 6),
                      LegendItem(color: AppColors.warning, label: 'Warning', count: count('WARNING')),
                      const SizedBox(height: 6),
                      LegendItem(color: AppColors.error, label: 'Critical', count: count('CRITICAL')),
                      const SizedBox(height: 6),
                      LegendItem(color: AppColors.offline, label: 'Offline', count: count('OFFLINE')),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    CircleIconButton(
                      tooltip: 'Zoom in',
                      elevated: true,
                      onTap: () => _zoom(1),
                      child: Icon(Icons.add_rounded, color: p.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    CircleIconButton(
                      tooltip: 'Zoom out',
                      elevated: true,
                      onTap: () => _zoom(-1),
                      child: Icon(Icons.remove_rounded, color: p.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    CircleIconButton(
                      tooltip: 'Show all vehicles',
                      elevated: true,
                      onTap: vehicles.isEmpty ? null : () => _fit(vehicles),
                      child: Icon(Icons.center_focus_strong_rounded, color: p.textPrimary),
                    ),
                  ],
                ),
              ),
              if (vehicles.isEmpty)
                Positioned.fill(
                  child: Container(
                    color: p.background.withAlpha(215),
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
                                title: state.loadError != null ? 'Map data unavailable' : 'No vehicle positions yet',
                                message: state.loadError != null
                                    ? 'Vehicle locations cannot be loaded right now.'
                                    : 'Vehicles appear on the map as soon as they report their location.',
                                actionLabel: state.loadError != null ? 'Retry' : null,
                                onAction: state.loadError != null ? state.loadAll : null,
                                color: state.loadError != null ? AppColors.error : null,
                                compact: true,
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        if (vehicles.isNotEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SingleChildScrollView(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final v in vehicles)
                      Padding(
                        padding: const EdgeInsets.only(right: _cardGap),
                        child: SizedBox(
                          width: _cardWidth,
                          child: _MapVehicleCard(
                            vehicle: v,
                            selected: v.id == _selectedId,
                            onTap: () => _select(v, vehicles, fromMap: false),
                            onDetails: () => _openDetails(v),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapVehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const _MapVehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
    required this.onDetails,
  });

  Widget _mini(BuildContext context, String label, String value) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: p.textSecondary)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final v = vehicle;
    final color = statusColor(v.status);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? Theme.of(context).colorScheme.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.directions_car_rounded, color: color, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.plate, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    Text(v.model, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              StatusChip(label: pretty(v.status), color: color),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _mini(context, 'Speed', '${num0(v.speed)} km/h'),
              _mini(context, 'Fuel', '${num0(v.fuel)} %'),
              _mini(context, 'Engine', '${num0(v.temp)} °C'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Updated ${timeAgo(v.lastUpdate)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.textMuted)),
              ),
              InkWell(
                onTap: onDetails,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Details',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
