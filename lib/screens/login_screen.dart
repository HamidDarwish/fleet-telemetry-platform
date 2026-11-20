import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/server_dialog.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../widgets/vehicle_health.dart';

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
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              child: SizedBox(
                height: 330 + top,
                child: Stack(
                  children: [
                    const Positioned.fill(child: HeroBackdrop()),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: ResponsiveBody(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: const VehicleCarArt(zones: false, dark: true),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      top: top + 40,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                          SizedBox(height: 6),
                          Text('Sign in to see how your vehicles are doing today.',
                              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 15, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                  : const Text('Sign in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Just trying it out? Pick a demo account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textSecondary)),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () async {
                                await showServerDialog(context);
                                if (mounted) setState(() {});
                              },
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: Text('Server: ${AppConfig.host}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
