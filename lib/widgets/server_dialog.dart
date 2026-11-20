import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

/// Lets the user change the backend address inside the installed app.
/// Returns true when a new address was saved.
Future<bool> showServerDialog(BuildContext context) async {
  final changed = await showDialog<bool>(context: context, builder: (_) => const _ServerDialog());
  return changed ?? false;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: AppConfig.host);
  String? _error;
  bool _testing = false;
  bool _saving = false;
  String? _result;
  bool _resultOk = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _clean() {
    final n = AppConfig.normalize(_ctrl.text);
    if (n == null) {
      setState(() => _error = 'Enter an address like 192.168.0.117:8080');
    } else {
      setState(() => _error = null);
    }
    return n;
  }

  Future<void> _test() async {
    final host = _clean();
    if (host == null) return;
    setState(() {
      _testing = true;
      _result = null;
    });
    bool ok;
    try {
      // Any HTTP answer (even 401) proves that the backend is there.
      await http.get(Uri.parse('http://$host/api/dashboard')).timeout(const Duration(seconds: 5));
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _resultOk = ok;
      _result = ok ? 'Server found at $host' : 'Cannot reach $host. Check the IP, the port and the Wi-Fi.';
    });
  }

  Future<void> _save() async {
    final host = _clean();
    if (host == null) return;
    setState(() => _saving = true);
    await context.read<AppState>().applyServer(host);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AlertDialog(
      title: const Text('Server address'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saving ? null : _save(),
              decoration: InputDecoration(
                labelText: 'IP address and port',
                hintText: '192.168.0.117:8080',
                errorText: _error,
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Emulator: ${AppConfig.defaultHost}\nReal phone: the IP of the computer that runs the backend '
              '(same Wi-Fi).',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing || _saving ? null : _test,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find_rounded, size: 18),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _ctrl.text = AppConfig.defaultHost),
                  child: const Text('Use default'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_resultOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 18, color: _resultOk ? AppColors.success : AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_result!, style: const TextStyle(fontSize: 13, height: 1.35))),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
