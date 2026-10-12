import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

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
    return MaterialApp(
      title: 'Fleet Telemetry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.initializing) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return state.session == null ? const LoginScreen() : const HomeShell();
        },
      ),
    );
  }
}
