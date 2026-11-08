import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';

/// FR-1.1
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  static const _demo = <(String, String, String)>[
    ('Admin', 'admin@fleet.local', 'admin123'),
    ('Manager', 'manager@fleet.local', 'manager123'),
    ('Technician', 'tech@fleet.local', 'tech123'),
    ('Driver', 'driver@fleet.local', 'driver123'),
  ];

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppState>().login(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x402563EB), blurRadius: 20, offset: Offset(0, 8))],
                      ),
                      child: const Icon(Icons.local_shipping_rounded, size: 38, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Fleet Telemetry',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text('Preventive Maintenance Platform',
                      textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: _hidePassword,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            NoticeBanner(message: _error!, icon: Icons.error_outline_rounded),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                  )
                                : const Text('Log in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Demo accounts',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in _demo)
                        FilterPill(
                          label: d.$1,
                          selected: false,
                          onTap: () {
                            _email.text = d.$2;
                            _password.text = d.$3;
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Server: ${AppConfig.host}',
                      textAlign: TextAlign.center, style: TextStyle(color: p.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
