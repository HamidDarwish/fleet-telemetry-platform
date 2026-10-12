import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

/// SIM-7: the System Admin starts and stops the simulator.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<AppState>().api.simulatorStatus();
      if (mounted) setState(() { _status = s; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(bool start) async {
    setState(() => _busy = true);
    try {
      final api = context.read<AppState>().api;
      final s = start ? await api.simulatorStart() : await api.simulatorStop();
      if (mounted) setState(() { _status = s; _error = null; });
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _status?['running'] == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Telemetry simulator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (_status != null)
                      StatusChip(label: running ? 'Running' : 'Stopped', color: running ? Colors.green : Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                if (_status != null) ...[
                  InfoRow('Virtual vehicles', '${_status!['vehicles']}'),
                  InfoRow('Interval', '${_status!['intervalMs']} ms'),
                  InfoRow('Speed multiplier', '${_status!['speedMultiplier']}x'),
                  InfoRow('Fault probability', '${_status!['faultProbability']}'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy || running ? null : () => _toggle(true),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy || !running ? null : () => _toggle(false),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Vehicle count, interval, speed multiplier and fault probability are set in the backend file '
            'application.properties (fleet.simulator.*).',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        InfoRow('Backend', AppConfig.host),
      ],
    );
  }
}
