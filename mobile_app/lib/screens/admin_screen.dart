import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/state_views.dart';
import '../widgets/theme_selector.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_widgets.dart';

/// SIM-7: the System Admin manages users, starts/stops the simulator and checks system health.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _status;
  bool _statusLoading = true;
  bool _busy = false;
  String? _error;

  List<UserInfo>? _users;
  bool _usersLoading = true;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadUsers();
  }

  Future<void> _loadStatus() async {
    if (mounted) setState(() => _statusLoading = true);
    try {
      final s = await context.read<AppState>().api.simulatorStatus();
      if (mounted) setState(() { _status = s; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    if (mounted) setState(() => _usersLoading = true);
    try {
      final u = await context.read<AppState>().api.users();
      if (mounted) setState(() { _users = u; _usersError = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _usersError = e.message);
    } catch (_) {
      if (mounted) setState(() => _usersError = 'The user list could not be read.');
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    final state = context.read<AppState>();
    await Future.wait([_loadStatus(), _loadUsers(), state.loadAll()]);
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
    final state = context.watch<AppState>();
    final p = AppPalette.of(context);
    final running = _status?['running'] == true;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ResponsiveBody(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ---------- System status ----------
            const SectionHeader(title: 'System status'),
            AppCard(
              child: Column(
                children: [
                  _StatusRow(
                    icon: Icons.dns_rounded,
                    label: 'Backend API',
                    value: state.loadError == null ? (state.loading ? 'Checking…' : 'Online') : 'Unreachable',
                    color: state.loadError == null ? (state.loading ? AppColors.warning : AppColors.success) : AppColors.error,
                  ),
                  const Divider(height: 20),
                  _StatusRow(
                    icon: Icons.sensors_rounded,
                    label: 'Live telemetry',
                    value: state.liveStatus == LiveStatus.connected
                        ? 'Connected'
                        : (state.liveStatus == LiveStatus.connecting ? 'Connecting' : 'Offline'),
                    color: state.liveStatus == LiveStatus.connected
                        ? AppColors.success
                        : (state.liveStatus == LiveStatus.connecting ? AppColors.warning : AppColors.error),
                  ),
                  const Divider(height: 20),
                  _StatusRow(
                    icon: Icons.precision_manufacturing_rounded,
                    label: 'Simulator',
                    value: _status == null ? (_statusLoading ? 'Checking…' : 'Unknown') : (running ? 'Running' : 'Stopped'),
                    color: _status == null ? AppColors.offline : (running ? AppColors.success : AppColors.offline),
                  ),
                  const Divider(height: 20),
                  _StatusRow(
                    icon: Icons.local_shipping_rounded,
                    label: 'Vehicles reporting',
                    value: '${state.vehicles.where((v) => v.hasPosition).length} / ${state.vehicles.length}',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            if (state.loadError != null) ...[
              const SizedBox(height: 10),
              NoticeBanner(message: state.loadError!, onRetry: state.loadAll, retrying: state.loading),
            ],

            // ---------- Simulator ----------
            const SizedBox(height: 24),
            const SectionHeader(title: 'Simulator controls'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(icon: Icons.precision_manufacturing_rounded, color: AppColors.primary, size: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Telemetry simulator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (_status != null)
                        StatusChip(
                          label: running ? 'Running' : 'Stopped',
                          color: running ? AppColors.success : AppColors.offline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    NoticeBanner(message: _error!, onRetry: _loadStatus, retrying: _statusLoading)
                  else if (_status == null)
                    const Column(children: [Skeleton(height: 56, radius: 12), SizedBox(height: 8), Skeleton(height: 56, radius: 12)])
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                              icon: Icons.directions_car_rounded, label: 'Virtual vehicles', value: '${_status!['vehicles']}', unit: ''),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricTile(icon: Icons.timer_outlined, label: 'Interval', value: '${_status!['intervalMs']}', unit: 'ms'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: MetricTile(
                              icon: Icons.fast_forward_rounded, label: 'Speed multiplier', value: '${_status!['speedMultiplier']}', unit: 'x'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MetricTile(
                              icon: Icons.report_problem_outlined, label: 'Fault probability', value: '${_status!['faultProbability']}', unit: ''),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy || running ? null : () => _toggle(true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy || !running ? null : () => _toggle(false),
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Stop'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),

            // ---------- Users ----------
            const SizedBox(height: 24),
            SectionHeader(
              title: 'User management',
              actionLabel: _usersError != null ? 'Retry' : null,
              onAction: _usersError != null ? _loadUsers : null,
            ),
            _UsersCard(users: _users, loading: _usersLoading, error: _usersError, onRetry: _loadUsers),

            // ---------- Configuration ----------
            const SizedBox(height: 24),
            const SectionHeader(title: 'Configuration & settings'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary)),
                  const SizedBox(height: 8),
                  const ThemeSelector(),
                  const Divider(height: 28),
                  InfoRow('Backend', AppConfig.host),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: p.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vehicle count, interval, speed multiplier and fault probability are set in the backend file '
                            'application.properties (fleet.simulator.*).',
                            style: TextStyle(color: p.textSecondary, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatusRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, color: color, size: 34),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        StatusChip(label: value, color: color),
      ],
    );
  }
}

class _UsersCard extends StatelessWidget {
  final List<UserInfo>? users;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  const _UsersCard({required this.users, required this.loading, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = users;

    if (list == null) {
      if (error != null) return NoticeBanner(message: error!, onRetry: onRetry, retrying: loading);
      return const ListSkeleton(count: 2);
    }
    if (list.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.group_outlined,
          title: 'No users found',
          message: 'User accounts will be listed here.',
          compact: true,
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: NoticeBanner(message: error!, onRetry: onRetry, retrying: loading),
            ),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: p.surfaceAlt,
                    child: Text(
                      list[i].name.isEmpty ? '?' : list[i].name[0].toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(list[i].email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(label: pretty(list[i].role), color: AppColors.primary, dot: false),
                      const SizedBox(height: 4),
                      Text(
                        list[i].active ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: list[i].active ? readableOn(context, AppColors.success) : p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
