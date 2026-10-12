import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'vehicles_screen.dart';

/// FR-5.1 .. FR-5.3: live map with status-colored markers (OpenStreetMap tiles).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _showVehicle(BuildContext context, Vehicle v) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${v.plate}  ·  ${v.model}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                StatusChip(label: pretty(v.status), color: statusColor(v.status)),
              ],
            ),
            const SizedBox(height: 8),
            InfoRow('Speed', '${v.speed?.toStringAsFixed(0) ?? '-'} km/h'),
            InfoRow('Fuel', '${v.fuel?.toStringAsFixed(0) ?? '-'} %'),
            InfoRow('Engine temperature', '${v.temp?.toStringAsFixed(0) ?? '-'} °C'),
            InfoRow('Last update', fmtTime(v.lastUpdate)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id)),
                );
              },
              child: const Text('Vehicle details'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicles = state.vehicles.where((v) => v.hasPosition).toList();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(initialCenter: LatLng(34.5281, 69.1723), initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.fleet_app',
            ),
            MarkerLayer(
              markers: [
                for (final v in vehicles)
                  Marker(
                    point: LatLng(v.lat!, v.lng!),
                    width: 70,
                    height: 56,
                    child: GestureDetector(
                      onTap: () => _showVehicle(context, v),
                      child: Column(
                        children: [
                          Icon(Icons.directions_car, color: statusColor(v.status), size: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor(v.status)),
                            ),
                            child: Text(v.plate, style: const TextStyle(fontSize: 9)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final s in ['NORMAL', 'WARNING', 'CRITICAL', 'OFFLINE'])
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 10, color: statusColor(s)),
                      const SizedBox(width: 6),
                      Text(pretty(s), style: const TextStyle(fontSize: 11)),
                    ]),
                ],
              ),
            ),
          ),
        ),
        if (vehicles.isEmpty)
          const Center(child: Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Waiting for vehicle data…')))),
      ],
    );
  }
}
