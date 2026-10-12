import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/common.dart';

/// FR-2.4: vehicle list.
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicles = state.vehicles;
    return RefreshIndicator(
      onRefresh: state.loadAll,
      child: vehicles.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No vehicles.')))])
          : ListView.separated(
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final v = vehicles[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor(v.status).withAlpha(40),
                    child: Icon(Icons.directions_car, color: statusColor(v.status)),
                  ),
                  title: Text('${v.plate}  ·  ${v.model}'),
                  subtitle: Text(
                      '${v.speed?.toStringAsFixed(0) ?? '-'} km/h · fuel ${v.fuel?.toStringAsFixed(0) ?? '-'}% · ${v.odometer?.toStringAsFixed(0) ?? '-'} km'),
                  trailing: StatusChip(label: pretty(v.status), color: statusColor(v.status)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id)),
                  ),
                );
              },
            ),
    );
  }
}

/// Vehicle detail: current values and maintenance rules with their status (FR-2.4, FR-6.3).
class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Future<List<RuleView>>? _rules;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final s = state.session!;
    if (s.isAdmin || s.isManager) {
      _rules = state.api.rules(widget.vehicleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.vehicles.where((x) => x.id == widget.vehicleId);
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Vehicle not found')));
    }
    final v = matches.first;

    return Scaffold(
      appBar: AppBar(title: Text(v.plate)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(v.model, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      StatusChip(label: pretty(v.status), color: statusColor(v.status)),
                    ],
                  ),
                  const Divider(),
                  InfoRow('Driver', v.driverName ?? '-'),
                  InfoRow('Speed', '${v.speed?.toStringAsFixed(0) ?? '-'} km/h'),
                  InfoRow('Fuel level', '${v.fuel?.toStringAsFixed(0) ?? '-'} %'),
                  InfoRow('Engine temperature', '${v.temp?.toStringAsFixed(0) ?? '-'} °C'),
                  InfoRow('Odometer', '${v.odometer?.toStringAsFixed(1) ?? '-'} km'),
                  InfoRow('Last update', fmtTime(v.lastUpdate)),
                ],
              ),
            ),
          ),
          if (_rules != null) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('Preventive maintenance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            FutureBuilder<List<RuleView>>(
              future: _rules,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) return Text('${snap.error}');
                final rules = snap.data ?? [];
                return Column(
                  children: [
                    for (final r in rules)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  StatusChip(label: pretty(r.status), color: ruleColor(r.status)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (r.percentUsed / 100).clamp(0.0, 1.0),
                                color: ruleColor(r.status),
                                backgroundColor: Colors.grey.shade200,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Every ${r.intervalValue} ${r.unit} · ${r.percentUsed.toStringAsFixed(0)}% used · '
                                '${r.remaining >= 0 ? '${r.remaining.toStringAsFixed(0)} ${r.unit} left' : '${(-r.remaining).toStringAsFixed(0)} ${r.unit} overdue'}',
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
