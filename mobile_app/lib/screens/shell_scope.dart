import 'package:flutter/material.dart';

/// Tabs that are available for the active session.
enum AppTab {
  dashboard,
  map,
  vehicles,
  alerts,
  orders,
  admin,
}

/// Shared navigation context for screens that live under the app shell.
class ShellScope extends InheritedWidget {
  final Set<AppTab> available;
  final void Function(AppTab tab) goTo;

  const ShellScope({
    super.key,
    required this.available,
    required this.goTo,
    required super.child,
  });

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  VoidCallback? action(AppTab tab) => available.contains(tab) ? () => goTo(tab) : null;

  @override
  bool updateShouldNotify(covariant ShellScope oldWidget) =>
      available != oldWidget.available || goTo != oldWidget.goTo;
}

