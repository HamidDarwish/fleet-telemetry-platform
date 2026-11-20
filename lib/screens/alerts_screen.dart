import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'vehicles_screen.dart';

/// FR-8.2, FR-8.5: alert list with acknowledge and filters.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _onlyOpen = false;
  String? _severity; // null = all
  final Set<int> _busy = {};

  Future<void> _acknowledge(int id, Future<void> Function() action) async {
    setState(() => _busy.add(id));
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.alerts;
    final items = all
        .where((a) => !_onlyOpen || !a.acknowledged)
        .where((a) => _severity == null || a.severity == _severity)
        .toList();
    int count(String s) => all.where((a) => a.severity == s).length;

    Widget body;
    if (all.isEmpty && state.loading) {
      body = const ListSkeleton(count: 4);
    } else if (all.isEmpty) {
      body = EmptyState(
        icon: state.loadError != null ? Icons.cloud_off_rounded : Icons.notifications_off_outlined,
        title: state.loadError != null ? 'Could not load alerts' : 'No alerts',
        message: state.loadError ?? 'You are all caught up. New alerts appear here in real time.',
        actionLabel: state.loadError != null ? 'Retry' : null,
        onAction: state.loadError != null ? state.loadAll : null,
        color: state.loadError != null ? AppColors.error : AppColors.success,
      );
    } else if (items.isEmpty) {
      body = EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: 'No alerts match',
        message: 'Change or clear the filters to see more alerts.',
        actionLabel: 'Clear filters',
        onAction: () => setState(() {
          _onlyOpen = false;
          _severity = null;
        }),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            AlertTile(
              alert: items[i],
              busy: _busy.contains(items[i].id),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: items[i].vehicleId)),
              ),
              onAcknowledge: () => _acknowledge(items[i].id, () => state.acknowledge(items[i])),
            ),
            if (i < items.length - 1) const SizedBox(height: 10),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentTabs(
              labels: ['All ${all.length}', 'Critical ${count('CRITICAL')}', 'Warning ${count('WARNING')}', 'Info ${count('INFO')}'],
              index: _severity == null ? 0 : const ['CRITICAL', 'WARNING', 'INFO'].indexOf(_severity!) + 1,
              onChanged: (i) => setState(() => _severity = i == 0 ? null : const ['CRITICAL', 'WARNING', 'INFO'][i - 1]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterPill(
                label: 'Only what I have not acknowledged',
                selected: _onlyOpen,
                color: AppColors.orange,
                onTap: () => setState(() => _onlyOpen = !_onlyOpen),
              ),
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
