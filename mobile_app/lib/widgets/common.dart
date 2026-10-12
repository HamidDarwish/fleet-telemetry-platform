import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

Color statusColor(String s) {
  switch (s) {
    case 'CRITICAL':
      return Colors.red;
    case 'WARNING':
      return Colors.orange;
    case 'OFFLINE':
      return Colors.grey;
    default:
      return Colors.green;
  }
}

Color severityColor(String s) {
  switch (s) {
    case 'CRITICAL':
      return Colors.red;
    case 'WARNING':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}

Color priorityColor(String p) {
  switch (p) {
    case 'CRITICAL':
      return Colors.red;
    case 'HIGH':
      return Colors.deepOrange;
    case 'LOW':
      return Colors.grey;
    default:
      return Colors.blue;
  }
}

Color ruleColor(String s) {
  switch (s) {
    case 'DUE':
      return Colors.red;
    case 'DUE_SOON':
      return Colors.orange;
    default:
      return Colors.green;
  }
}

String fmtTime(DateTime? t) => t == null ? '-' : DateFormat('MM-dd HH:mm:ss').format(t);

/// "ENGINE_OVERHEAT" -> "Engine overheat"
String pretty(String s) {
  final t = s.replaceAll('_', ' ').toLowerCase();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class AlertTile extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAcknowledge;
  const AlertTile({super.key, required this.alert, this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(alert.severity);
    return ListTile(
      leading: Icon(
        alert.severity == 'CRITICAL' ? Icons.error : Icons.warning_amber_rounded,
        color: alert.acknowledged ? Colors.grey : color,
      ),
      title: Text(alert.message),
      subtitle: Text('${pretty(alert.type)} · ${fmtTime(alert.createdAt)}'),
      trailing: alert.acknowledged
          ? const Icon(Icons.check_circle, color: Colors.green)
          : (onAcknowledge == null
              ? null
              : IconButton(
                  tooltip: 'Acknowledge',
                  icon: const Icon(Icons.done),
                  onPressed: onAcknowledge,
                )),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
  );
}
