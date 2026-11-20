import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..restore(),
      child: const FleetApp(),
    ),
  );
}

class FleetApp extends StatelessWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Fleet Telemetry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Very large system fonts break layouts, so text scaling is kept within a comfortable range.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.1)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Consumer<AppState>(
        builder: (context, state, _) {
          final Widget page;
          if (state.initializing) {
            page = const _Splash(key: ValueKey('splash'));
          } else if (state.session == null) {
            page = const LoginScreen(key: ValueKey('login'));
          } else {
            page = const HomeShell(key: ValueKey('home'));
          }
          return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: page);
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppColors.primary,
              ),
              child: const Icon(Icons.local_shipping_rounded, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('Fleet Telemetry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Restoring your session…', style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 20),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6)),
          ],
        ),
      ),
    );
  }
}
