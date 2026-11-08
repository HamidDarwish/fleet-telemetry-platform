import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/fleet_map.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_widgets.dart';
import 'work_orders_screen.dart';

/// FR-2.4: searchable vehicle list.
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _status; // null = all

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Vehicle v) {
    if (_status != null && v.status != _status) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return v.plate.toLowerCase().contains(q) ||
        v.model.toLowerCase().contains(q) ||
        (v.driverName ?? '').toLowerCase().contains(q);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final vehicles = state.vehicles;
    final filtered = vehicles.where(_matches).toList();
    int count(String s) => vehicles.where((v) => v.status == s).length;

    Widget body;
    if (vehicles.isEmpty && state.loading) {
      body = const ListSkeleton(count: 4);
    } else if (vehicles.isEmpty) {
      body = EmptyState(
        icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.directions_car_outlined,
        title: state.loadError != null ? 'Could not load vehicles' : 'No vehicles yet',
        message: state.loadError ?? 'Vehicles assigned to you will be listed here.',
        actionLabel: state.loadError != null ? 'Retry' : null,
        onAction: state.loadError != null ? state.loadAll : null,
        color: state.loadError != null ? AppColors.error : null,
      );
    } else if (filtered.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching vehicles',
        message: 'Try a different search or clear the filters.',
        actionLabel: 'Clear filters',
        onAction: _clearFilters,
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < filtered.length; i++) ...[
            VehicleCard(
              vehicle: filtered[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: filtered[i].id)),
              ),
            ),
            if (i < filtered.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return ResponsiveBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search plate, model or driver',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterPill(
                  label: 'All',
                  count: vehicles.length,
                  selected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
                const SizedBox(width: 8),
                for (final s in ['NORMAL', 'WARNING', 'CRITICAL', 'OFFLINE']) ...[
                  FilterPill(
                    label: s == 'NORMAL' ? 'Active' : pretty(s),
                    count: count(s),
                    color: statusColor(s),
                    selected: _status == s,
                    onTap: () => setState(() => _status = _status == s ? null : s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

/// Vehicle detail: live values, location, maintenance rules and history (FR-2.4, FR-6.3).
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
    _loadRules();
  }

  void _loadRules() {
    final state = context.read<AppState>();
    final s = state.session!;
    if (s.isAdmin || s.isManager) {
      _rules = state.api.rules(widget.vehicleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = AppPalette.of(context);
    final matches = state.vehicles.where((x) => x.id == widget.vehicleId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Vehicle not found',
          message: 'It may have been removed or is no longer assigned to you.',
        ),
      );
    }
    final v = matches.first;
    final color = statusColor(v.status);
    final session = state.session!;
    final history = (session.isManager || session.isTechnician)
        ? (state.workOrders.where((w) => w.vehicleId == v.id).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000))))
        : <WorkOrder>[];

    return Scaffold(
      appBar: AppBar(title: Text(v.plate)),
      body: SafeArea(
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(icon: Icons.directions_car_rounded, color: color, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.model.isEmpty ? 'Unknown model' : v.model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Updated ${timeAgo(v.lastUpdate)}',
                                  style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                            ],
                          ),
                        ),
                        StatusChip(label: pretty(v.status), color: color),
                      ],
                    ),
                    const SizedBox(height: 14),
                    VehicleMetrics(vehicle: v),
                    const SizedBox(height: 8),
                    InfoRow('Driver', v.driverName ?? '-'),
                    const Divider(height: 8),
                    InfoRow('Odometer', '${v.odometer?.toStringAsFixed(1) ?? '-'} km'),
                    const Divider(height: 8),
                    InfoRow('Last update', fmtTime(v.lastUpdate)),
                  ],
                ),
              ),
              if (v.hasPosition) ...[
                const SizedBox(height: 16),
                const SectionHeader(title: 'Location'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card - 1),
                    child: SizedBox(
                      height: 170,
                      child: IgnorePointer(child: FleetMap(vehicles: [v], interactive: false, compact: true)),
                    ),
                  ),
                ),
              ],
              if (_rules != null) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Preventive maintenance'),
                FutureBuilder<List<RuleView>>(
                  future: _rules,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const ListSkeleton(count: 2);
                    }
                    if (snap.hasError) {
                      return NoticeBanner(
                        message: '${snap.error}',
                        onRetry: () => setState(_loadRules),
                      );
                    }
                    final rules = snap.data ?? [];
                    if (rules.isEmpty) {
                      return const AppCard(
                        child: EmptyState(
                          icon: Icons.build_circle_outlined,
                          title: 'No maintenance rules',
                          message: 'No service intervals are configured for this vehicle.',
                          compact: true,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final r in rules) ...[
                          AppCard(padding: const EdgeInsets.all(14), child: RuleTile(rule: r)),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
              if (session.isManager || session.isTechnician) ...[
                const SizedBox(height: 14),
                const SectionHeader(title: 'Maintenance history'),
                if (history.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No work orders yet',
                      message: 'Work orders for this vehicle will be listed here.',
                      compact: true,
                    ),
                  )
                else
                  for (final w in history) ...[
                    WorkOrderCard(
                      order: w,
                      showVehicle: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(orderId: w.id)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
