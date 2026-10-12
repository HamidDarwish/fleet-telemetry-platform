import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';

/// FR-8.2, FR-8.5: alert list with acknowledge and a simple filter.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _onlyOpen = false;
  String? _severity; // null = all

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.alerts
        .where((a) => !_onlyOpen || !a.acknowledged)
        .where((a) => _severity == null || a.severity == _severity)
        .toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Not acknowledged'),
                selected: _onlyOpen,
                onSelected: (v) => setState(() => _onlyOpen = v),
              ),
              const SizedBox(width: 8),
              for (final s in ['CRITICAL', 'WARNING', 'INFO']) ...[
                ChoiceChip(
                  label: Text(pretty(s)),
                  selected: _severity == s,
                  onSelected: (v) => setState(() => _severity = v ? s : null),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: state.loadAll,
            child: items.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No alerts.')))])
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = items[i];
                      return AlertTile(
                        alert: a,
                        onAcknowledge: () async {
                          try {
                            await context.read<AppState>().acknowledge(a);
                          } catch (e) {
                            if (context.mounted) showMessage(context, '$e', error: true);
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
