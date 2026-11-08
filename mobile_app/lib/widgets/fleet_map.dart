import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import 'common.dart';

/// Colored vehicle marker. [compact] is a plain dot for small previews.
class VehiclePin extends StatelessWidget {
  final Vehicle vehicle;
  final bool compact;
  final bool selected;

  const VehiclePin({super.key, required this.vehicle, this.compact = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(vehicle.status);
    const shadow = [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))];

    if (compact) {
      return Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: shadow,
          ),
        ),
      );
    }

    final size = selected ? 44.0 : 34.0;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: shadow,
          ),
          child: Icon(Icons.directions_car_rounded, color: Colors.white, size: selected ? 22 : 18),
        ),
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color),
            ),
            child: Text(
              vehicle.plate,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }
}

/// OpenStreetMap view with status-colored vehicle markers.
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

  const FleetMap({
    super.key,
    required this.vehicles,
    this.controller,
    this.interactive = true,
    this.compact = false,
    this.selectedId,
    this.onVehicleTap,
  });

  static LatLng get defaultCenter => LatLng(34.5281, 69.1723);

  static const ColorFilter _darkTiles = ColorFilter.matrix(<double>[
    -0.9, 0, 0, 0, 240, //
    0, -0.9, 0, 0, 240,
    0, 0, -0.9, 0, 245,
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
    final tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.fleet_app',
      tileProvider: NetworkTileProvider(),
      errorTileCallback: (_, __, ___) {},
    );
    final positioned = vehicles.where((v) => v.hasPosition).toList();
    final markerSize = compact ? 24.0 : 76.0;

    return FlutterMap(
      key: controller == null ? ValueKey<int>(positioned.length >= 2 ? 2 : positioned.length) : null,
      mapController: controller,
      options: _options(),
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101B2A) : const Color(0xFFEAF2F8),
            ),
          ),
        ),
        if (isDark) ColorFiltered(colorFilter: _darkTiles, child: tiles) else tiles,
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
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}
