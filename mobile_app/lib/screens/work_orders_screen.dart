import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

/// FR-7: work order list.
class WorkOrdersScreen extends StatelessWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final orders = state.workOrders;
    return RefreshIndicator(
      onRefresh: state.loadAll,
      child: orders.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No work orders.')))])
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final w = orders[i];
                return Card(
                  child: ListTile(
                    title: Text(w.title),
                    subtitle: Text(
                        '${w.plate} · ${pretty(w.source)} · ${w.assignedToName ?? 'unassigned'}\n${fmtTime(w.createdAt)}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(label: pretty(w.status), color: w.status == 'COMPLETED' ? Colors.green : Colors.indigo),
                        const SizedBox(height: 4),
                        StatusChip(label: pretty(w.priority), color: priorityColor(w.priority)),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(orderId: w.id)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Assign (manager), start, add notes/parts/cost and close (FR-7.2 .. FR-7.4).
class WorkOrderDetailScreen extends StatefulWidget {
  final int orderId;
  const WorkOrderDetailScreen({super.key, required this.orderId});

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  final _notes = TextEditingController();
  final _parts = TextEditingController();
  final _cost = TextEditingController();
  List<TechnicianInfo> _technicians = [];
  int? _assignedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final w = state.workOrders.firstWhere((x) => x.id == widget.orderId);
    _notes.text = w.notes;
    _parts.text = w.parts;
    _cost.text = w.cost == null ? '' : w.cost!.toStringAsFixed(2);
    _assignedId = w.assignedToId;
    if (state.session!.isManager) {
      state.api.technicians().then((list) {
        if (mounted) setState(() => _technicians = list);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _parts.dispose();
    _cost.dispose();
    super.dispose();
  }

  Map<String, dynamic> _fields() => {
        'notes': _notes.text,
        'parts': _parts.text,
        if (double.tryParse(_cost.text.trim()) != null) 'cost': double.parse(_cost.text.trim()),
      };

  Future<void> _send(Map<String, dynamic> changes, String okMessage) async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().updateWorkOrder(widget.orderId, changes);
      if (mounted) showMessage(context, okMessage);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = state.workOrders.where((x) => x.id == widget.orderId);
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Work order not found')));
    }
    final w = matches.first;
    final isManager = state.session!.isManager;
    final active = w.status == 'OPEN' || w.status == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(title: Text('Work order #${w.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(w.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            StatusChip(label: pretty(w.status), color: Colors.indigo),
            StatusChip(label: pretty(w.priority), color: priorityColor(w.priority)),
            StatusChip(label: pretty(w.source), color: Colors.grey),
          ]),
          const SizedBox(height: 12),
          InfoRow('Vehicle', w.plate),
          InfoRow('Created', fmtTime(w.createdAt)),
          InfoRow('Assigned to', w.assignedToName ?? 'unassigned'),
          if (w.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(w.description, style: const TextStyle(color: Colors.black87)),
          ],
          const Divider(height: 32),
          if (isManager && active) ...[
            DropdownButtonFormField<int>(
              value: _technicians.any((t) => t.id == _assignedId) ? _assignedId : null,
              decoration: const InputDecoration(labelText: 'Assign to technician', border: OutlineInputBorder()),
              items: [for (final t in _technicians) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: (v) => setState(() => _assignedId = v),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy || _assignedId == null
                  ? null
                  : () => _send({'assignedToId': _assignedId}, 'Technician assigned'),
              child: const Text('Assign'),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _notes,
            enabled: active,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _parts,
            enabled: active,
            decoration: const InputDecoration(labelText: 'Parts used', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            enabled: active,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cost', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (active) ...[
            OutlinedButton(
              onPressed: _busy ? null : () => _send(_fields(), 'Saved'),
              child: const Text('Save notes, parts and cost'),
            ),
            const SizedBox(height: 8),
            if (w.status == 'OPEN')
              FilledButton(
                onPressed: _busy ? null : () => _send({..._fields(), 'status': 'IN_PROGRESS'}, 'Work started'),
                child: const Text('Start work'),
              ),
            if (w.status == 'IN_PROGRESS')
              FilledButton(
                onPressed: _busy ? null : () => _send({..._fields(), 'status': 'COMPLETED'}, 'Work order completed'),
                child: const Text('Complete work order'),
              ),
            if (isManager) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _send({'status': 'CANCELLED'}, 'Work order cancelled'),
                child: const Text('Cancel work order', style: TextStyle(color: Colors.red)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
