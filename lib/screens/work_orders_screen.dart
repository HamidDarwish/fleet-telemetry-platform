import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';

/// Work order summary card, also used in the vehicle maintenance history.
class WorkOrderCard extends StatelessWidget {
  final WorkOrder order;
  final bool showVehicle;
  final VoidCallback? onTap;
  const WorkOrderCard({super.key, required this.order, this.showVehicle = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final w = order;
    final meta = [
      if (showVehicle && w.plate.isNotEmpty) w.plate,
      pretty(w.source),
      w.assignedToName ?? 'Unassigned',
    ].join(' · ');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: Icons.build_rounded, color: workOrderStatusColor(w.status), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: pretty(w.status), color: workOrderStatusColor(w.status)),
              StatusChip(label: pretty(w.priority), color: priorityColor(w.priority), dot: false),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: p.textMuted),
                  const SizedBox(width: 4),
                  Text(timeAgo(w.createdAt), style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// FR-7: work order list.
class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  String? _status; // null = all

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.workOrders;
    final orders = all.where((w) => _status == null || w.status == _status).toList();
    int count(String s) => all.where((w) => w.status == s).length;

    Widget body;
    if (all.isEmpty && state.loading) {
      body = const ListSkeleton(count: 3);
    } else if (all.isEmpty) {
      body = EmptyState(
        icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.assignment_turned_in_outlined,
        title: state.loadError != null ? 'Could not load work orders' : 'No work orders',
        message: state.loadError ?? 'Work orders created by alerts or managers will be listed here.',
        actionLabel: state.loadError != null ? 'Retry' : null,
        onAction: state.loadError != null ? state.loadAll : null,
        color: state.loadError != null ? AppColors.error : null,
      );
    } else if (orders.isEmpty) {
      body = EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'No work orders with this status',
        actionLabel: 'Show all',
        onAction: () => setState(() => _status = null),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < orders.length; i++) ...[
            WorkOrderCard(
              order: orders[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(orderId: orders[i].id)),
              ),
            ),
            if (i < orders.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return ResponsiveBody(
      child: Column(
        children: [
          if (state.loadError != null && all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: NoticeBanner(message: state.loadError!, onRetry: state.loadAll, retrying: state.loading),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterPill(
                  label: 'All',
                  count: all.length,
                  selected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                const SizedBox(width: 8),
                for (final s in ['OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']) ...[
                  FilterPill(
                    label: pretty(s),
                    count: count(s),
                    color: workOrderStatusColor(s),
                    selected: _status == s,
                    onTap: () => setState(() => _status = _status == s ? null : s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [body],
              ),
            ),
          ),
        ],
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

  bool _hasValidCost() {
    final raw = _cost.text.trim();
    if (raw.isEmpty) return true;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value < 0) {
      showMessage(context, 'Enter a valid non-negative cost.', error: true);
      return false;
    }
    return true;
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel work order?'),
        content: const Text('This will close the work order as cancelled. You cannot restart it afterward.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep open')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel work order'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _send({'status': 'CANCELLED'}, 'Work order cancelled');
    }
  }

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
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.assignment_late_outlined,
          title: 'Work order not found',
          message: 'It may have been removed or reassigned.',
        ),
      );
    }
    final w = matches.first;
    final isManager = state.session!.isManager;
    final active = w.status == 'OPEN' || w.status == 'IN_PROGRESS';

    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Work order #${w.id}')),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      StatusChip(label: pretty(w.status), color: workOrderStatusColor(w.status)),
                      StatusChip(label: pretty(w.priority), color: priorityColor(w.priority), dot: false),
                      StatusChip(label: pretty(w.source), color: AppColors.offline, dot: false),
                    ]),
                    const SizedBox(height: 12),
                    InfoRow('Vehicle', w.plate),
                    const Divider(height: 8),
                    InfoRow('Created', fmtTime(w.createdAt)),
                    const Divider(height: 8),
                    InfoRow('Assigned to', w.assignedToName ?? 'unassigned'),
                    if (w.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(w.description, style: TextStyle(color: p.textSecondary, height: 1.4)),
                    ],
                  ],
                ),
              ),
              if (isManager && active) ...[
                const SizedBox(height: 16),
                const SectionHeader(title: 'Assignment'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey<int?>(_technicians.any((t) => t.id == _assignedId) ? _assignedId : null),
                        initialValue: _technicians.any((t) => t.id == _assignedId) ? _assignedId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Assign to technician'),
                        items: [for (final t in _technicians) DropdownMenuItem(value: t.id, child: Text(t.name))],
                        onChanged: (v) => setState(() => _assignedId = v),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy || _assignedId == null
                            ? null
                            : () => _send({'assignedToId': _assignedId}, 'Technician assigned'),
                        child: const Text('Assign'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const SectionHeader(title: 'Work details'),
              AppCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _notes,
                      enabled: active,
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _parts,
                      enabled: active,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Parts used'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cost,
                      enabled: active,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Cost'),
                    ),
                  ],
                ),
              ),
              if (active) ...[
                const SizedBox(height: 16),
                if (_busy) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_hasValidCost()) _send(_fields(), 'Saved');
                        },
                  child: const Text('Save notes, parts and cost'),
                ),
                const SizedBox(height: 10),
                if (w.status == 'OPEN')
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_hasValidCost()) _send({..._fields(), 'status': 'IN_PROGRESS'}, 'Work started');
                          },
                    child: const Text('Start work'),
                  ),
                if (w.status == 'IN_PROGRESS')
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (_hasValidCost()) _send({..._fields(), 'status': 'COMPLETED'}, 'Work order completed');
                          },
                    child: const Text('Complete work order'),
                  ),
                if (isManager) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : _confirmCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Cancel work order'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
