import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

Color statusColor(String s) {
  switch (s) {
    case 'CRITICAL':
      return AppColors.error;
    case 'WARNING':
      return AppColors.warning;
    case 'OFFLINE':
      return AppColors.offline;
    default:
      return AppColors.success;
  }
}

Color severityColor(String s) {
  switch (s) {
    case 'CRITICAL':
      return AppColors.error;
    case 'WARNING':
      return AppColors.warning;
    default:
      return AppColors.primary;
  }
}

IconData severityIcon(String s) {
  switch (s) {
    case 'CRITICAL':
      return Icons.error_rounded;
    case 'WARNING':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_rounded;
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'CRITICAL':
      return AppColors.error;
    case 'HIGH':
      return AppColors.orange;
    case 'LOW':
      return AppColors.offline;
    default:
      return AppColors.primary;
  }
}

Color ruleColor(String s) {
  switch (s) {
    case 'DUE':
      return AppColors.error;
    case 'DUE_SOON':
      return AppColors.warning;
    default:
      return AppColors.success;
  }
}

Color workOrderStatusColor(String s) {
  switch (s) {
    case 'COMPLETED':
      return AppColors.success;
    case 'IN_PROGRESS':
      return AppColors.warning;
    case 'CANCELLED':
      return AppColors.offline;
    default:
      return AppColors.primary;
  }
}

String fmtTime(DateTime? t) => t == null ? '-' : DateFormat('MM-dd HH:mm:ss').format(t);

/// "5m ago", "2h ago" or a short date for older values.
String timeAgo(DateTime? t) {
  if (t == null) return '-';
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('MMM d, HH:mm').format(t);
}

/// "ENGINE_OVERHEAT" -> "Engine overheat"
String pretty(String s) {
  final t = s.replaceAll('_', ' ').toLowerCase();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Rounded number for display, or a dash when the value is unknown.
String num0(double? v) => v == null ? '–' : v.toStringAsFixed(0);

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;
  const StatusChip({super.key, required this.label, required this.color, this.dot = true});

  @override
  Widget build(BuildContext context) {
    final fg = readableOn(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Alert card: severity icon, vehicle, message, time and an optional acknowledge action.
class AlertTile extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAcknowledge;
  final bool busy;
  final bool compact;
  final VoidCallback? onTap;
  const AlertTile(
      {super.key, required this.alert, this.onAcknowledge, this.busy = false, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = alert.acknowledged ? AppColors.offline : severityColor(alert.severity);
    final highlight = !alert.acknowledged && alert.severity == 'CRITICAL';

    Widget? trailing;
    if (alert.acknowledged) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
          const SizedBox(width: 4),
          Text('Acknowledged',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: readableOn(context, AppColors.success))),
        ],
      );
    } else if (onAcknowledge != null) {
      trailing = FilledButton.tonal(
        onPressed: busy ? null : onAcknowledge,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Acknowledge'),
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: highlight ? color.withAlpha(110) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: severityIcon(alert.severity), color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.plate.isEmpty ? 'Vehicle #${alert.vehicleId}' : alert.plate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(label: pretty(alert.severity), color: color, dot: false),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: alert.acknowledged ? p.textSecondary : p.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: p.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${timeAgo(alert.createdAt)} · ${pretty(alert.type)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                      ),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 8), trailing],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.textSecondary, fontSize: 13.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
}
