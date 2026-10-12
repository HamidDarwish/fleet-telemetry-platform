import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';

/// FR-5.5
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget _tile(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = state.dashboard;
    return RefreshIndicator(
      onRefresh: state.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (state.loadError != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(state.loadError!)),
            ),
          if (d == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.9,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _tile('Vehicles online', '${d.activeVehicles} / ${d.totalVehicles}', Icons.directions_car, Colors.indigo),
                _tile('Critical vehicles', '${d.criticalVehicles}', Icons.error, Colors.red),
                _tile('Open alerts', '${d.openAlerts}', Icons.notifications_active, Colors.orange),
                _tile('Open work orders', '${d.openWorkOrders}', Icons.build, Colors.blue),
                _tile('Maintenance due', '${d.maintenanceDue}', Icons.event_busy, Colors.deepOrange),
              ],
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text('Recent alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (state.alerts.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No alerts yet.'))
          else
            for (final a in state.alerts.take(6)) AlertTile(alert: a),
        ],
      ),
    );
  }
}
