import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'ui.dart';

/// Small tinted tile showing one telemetry value (speed, fuel, temperature…).
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final double? progress;
  final Color? progressColor;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: p.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                TextSpan(text: ' $unit', style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
              ]),
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            AppProgress(value: progress!, color: progressColor ?? AppColors.primary, height: 4),
          ],
        ],
      ),
    );
  }
}

/// The three live values every vehicle view shows.
class VehicleMetrics extends StatelessWidget {
  final Vehicle vehicle;
  const VehicleMetrics({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    return Row(
      children: [
        Expanded(
          child: MetricTile(icon: Icons.speed_rounded, label: 'Speed', value: num0(v.speed), unit: 'km/h'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(
            icon: Icons.local_gas_station_rounded,
            label: 'Fuel',
            value: num0(v.fuel),
            unit: '%',
            progress: v.fuel == null ? null : v.fuel! / 100,
            progressColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: MetricTile(icon: Icons.thermostat_rounded, label: 'Engine', value: num0(v.temp), unit: '°C'),
        ),
      ],
    );
  }
}

/// Vehicle list card: identity, status, live metrics and driver.
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;
  const VehicleCard({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final v = vehicle;
    final color = statusColor(v.status);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.directions_car_rounded, color: color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(v.model.isEmpty ? 'Unknown model' : v.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: pretty(v.status), color: color),
            ],
          ),
          const SizedBox(height: 12),
          VehicleMetrics(vehicle: v),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 15, color: p.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(v.driverName ?? 'No driver assigned',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 14, color: p.textMuted),
              const SizedBox(width: 4),
              Text(timeAgo(v.lastUpdate), style: TextStyle(fontSize: 12, color: p.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Preventive maintenance rule with progress toward its next service.
class RuleTile extends StatelessWidget {
  final RuleView rule;
  final String? plate;
  const RuleTile({super.key, required this.rule, this.plate});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = rule;
    final color = ruleColor(r.status);
    final remaining = r.remaining >= 0
        ? '${r.remaining.toStringAsFixed(0)} ${r.unit} left'
        : '${(-r.remaining).toStringAsFixed(0)} ${r.unit} overdue';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            StatusChip(label: pretty(r.status), color: color),
          ],
        ),
        if (plate != null && plate!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(plate!, style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ],
        const SizedBox(height: 8),
        AppProgress(value: r.percentUsed / 100, color: color),
        const SizedBox(height: 6),
        Text(
          'Every ${r.intervalValue} ${r.unit} · ${r.percentUsed.toStringAsFixed(0)}% used · $remaining',
          style: TextStyle(color: p.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
