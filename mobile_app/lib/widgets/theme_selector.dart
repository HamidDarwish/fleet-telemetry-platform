import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.select<AppState, ThemeMode>((s) => s.themeMode);

    return DropdownMenu<ThemeMode>(
      initialSelection: current,
      leadingIcon: const Icon(Icons.brightness_6_rounded),
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: ThemeMode.system, label: 'System'),
        DropdownMenuEntry(value: ThemeMode.light, label: 'Light'),
        DropdownMenuEntry(value: ThemeMode.dark, label: 'Dark'),
      ],
      onSelected: (mode) {
        if (mode != null) {
          context.read<AppState>().setThemeMode(mode);
        }
      },
    );
  }
}
