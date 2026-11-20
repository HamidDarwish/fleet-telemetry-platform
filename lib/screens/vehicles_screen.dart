import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_health.dart';
import '../widgets/vehicle_widgets.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicles = [...state.vehicles];

    return RefreshIndicator(
      onRefresh: state.loadAll,
      child: ResponsiveBody(
        child: vehicles.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (state.loading)
                    const ListSkeleton(count: 3)
                  else
                    AppCard(
                      child: EmptyState(
                        icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.directions_car_filled_rounded,
                        title: state.loadError != null ? 'Vehicles unavailable' : 'No vehicles yet',
                        message: state.loadError != null
                            ? 'The vehicle list could not be loaded.'
                            : 'New vehicles appear here as soon as the fleet is synced.',
                        actionLabel: state.loadError != null ? 'Retry' : null,
                        onAction: state.loadError != null ? state.loadAll : null,
                        color: state.loadError != null ? AppColors.error : null,
                        compact: true,
                      ),
                    ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final vehicle in vehicles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VehicleCard(
                        vehicle: vehicle,
                        issues: vehicleIssues(vehicle, state.alerts, state.rules),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id)),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class VehicleDetailScreen extends StatelessWidget {
  final int vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicle = state.vehicles.where((v) => v.id == vehicleId).firstOrNull;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle')),
        body: const Center(child: Text('Vehicle not found')),
      );
    }

    final issues = vehicleIssues(vehicle, state.alerts, state.rules);
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.plate.isEmpty ? 'Vehicle #$vehicleId' : vehicle.plate),
      ),
      body: RefreshIndicator(
        onRefresh: state.loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.model.isEmpty ? 'Unknown model' : vehicle.model,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  StatusChip(label: pretty(vehicle.status), color: statusColor(vehicle.status)),
                  const SizedBox(height: 12),
                  SizedBox(width: 220, child: VehicleCarArt(vehicle: vehicle, issues: issues, zones: false)),
                  const SizedBox(height: 12),
                  VehicleMetrics(vehicle: vehicle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: VehicleHealthView(vehicle: vehicle, issues: issues),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fleet details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary)),
                  const SizedBox(height: 12),
                  _infoRow(context, 'Driver', vehicle.driverName ?? 'No driver assigned'),
                  _infoRow(context, 'Last update', timeAgo(vehicle.lastUpdate)),
                  _infoRow(context, 'Fuel', vehicle.fuel == null ? 'Unknown' : '${vehicle.fuel!.toStringAsFixed(0)} %'),
                  _infoRow(context, 'Engine temp', vehicle.temp == null ? 'Unknown' : '${vehicle.temp!.toStringAsFixed(0)} °C'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: p.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

