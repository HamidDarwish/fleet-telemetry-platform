import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Glowing vehicle marker. [compact] is a plain glowing dot for small previews.
class VehiclePin extends StatelessWidget {
  final Vehicle vehicle;
  final bool compact;
  final bool selected;

  const VehiclePin({super.key, required this.vehicle, this.compact = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(vehicle.status);
    final pal = AppPalette.of(context);

    if (compact) {
      return Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: [BoxShadow(color: color.withAlpha(150), blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      );
    }

    final core = selected ? 40.0 : 32.0;
    Widget ring(double size, int alpha) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(alpha),
            border: Border.all(color: color.withAlpha(alpha + 40), width: 1),
          ),
        );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ring(selected ? 96 : 70, 26),
        ring(selected ? 68 : 52, 40),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: core,
          height: core,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: color.withAlpha(190), blurRadius: 16, spreadRadius: 1)],
          ),
          child: Icon(Icons.navigation_rounded, color: Colors.white, size: selected ? 22 : 18),
        ),
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? color : pal.surface.withAlpha(240),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(selected ? 255 : 150)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: selected ? Colors.white : color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  vehicle.plate,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : pal.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Map that follows the app theme (OpenStreetMap tiles, navy filter in dark mode) with glowing status-colored vehicle markers.
///
/// Pass only vehicles that have a position. Without a [controller] the map re-fits itself
/// when the number of positioned vehicles changes (used for the non-interactive preview).
class FleetMap extends StatelessWidget {
  final List<Vehicle> vehicles;
  final MapController? controller;
  final bool interactive;
  final bool compact;
  final int? selectedId;
  final ValueChanged<Vehicle>? onVehicleTap;
  final bool showAttribution;

  const FleetMap({
    super.key,
    required this.vehicles,
    this.controller,
    this.interactive = true,
    this.compact = false,
    this.selectedId,
    this.onVehicleTap,
    this.showAttribution = true,
  });

  static LatLng get defaultCenter => LatLng(34.5281, 69.1723);

  static const ColorFilter _navyTiles = ColorFilter.matrix(<double>[
    -0.8, 0, 0, 0, 215, //
    0, -0.8, 0, 0, 222,
    0, 0, -0.8, 0, 245,
    0, 0, 0, 1, 0,
  ]);

  MapOptions _options() {
    final points = <LatLng>[
      for (final v in vehicles)
        if (v.hasPosition) LatLng(v.lat!, v.lng!),
    ];
    final flags = interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none;
    final interaction = InteractionOptions(flags: flags);
    if (points.length >= 2) {
      return MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: EdgeInsets.all(compact ? 32 : 56),
          maxZoom: 16,
        ),
        interactionOptions: interaction,
        minZoom: 3,
        maxZoom: 18,
      );
    }
    if (points.length == 1) {
      return MapOptions(
        initialCenter: points.first,
        initialZoom: 14,
        interactionOptions: interaction,
        minZoom: 3,
        maxZoom: 18,
      );
    }
    return MapOptions(
      initialCenter: defaultCenter,
      initialZoom: 12,
      interactionOptions: interaction,
      minZoom: 3,
      maxZoom: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Free OpenStreetMap tiles (no API key); in the dark theme they get a navy color filter.
    // OpenStreetMap can refuse apps whose package name starts with "com.example", so the app
    // identifies itself with its own name. If a tile still fails, a second free source is used.
    final tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      fallbackUrl: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.pixelpy.fleet_telemetry',
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
    );
    final positioned = vehicles.where((v) => v.hasPosition).toList();
    final markerSize = compact ? 28.0 : 110.0;

    return FlutterMap(
      key: controller == null ? ValueKey<int>(positioned.length >= 2 ? 2 : positioned.length) : null,
      mapController: controller,
      options: _options(),
      children: [
        if (isDark) ColorFiltered(colorFilter: _navyTiles, child: tiles) else tiles,
        MarkerLayer(
          markers: [
            for (final v in positioned)
              Marker(
                point: LatLng(v.lat!, v.lng!),
                width: markerSize,
                height: markerSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onVehicleTap == null ? null : () => onVehicleTap!(v),
                  child: VehiclePin(vehicle: v, compact: compact, selected: v.id == selectedId),
                ),
              ),
          ],
        ),
        if (showAttribution)
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors'),
              TextSourceAttribution('Esri'),
            ],
          ),
      ],
    );
  }
}
