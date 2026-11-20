import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  const NavBarItem({required this.icon, required this.selectedIcon, required this.label, this.badge = 0});
}

/// Floating bottom navigation bar with an animated selection indicator.
class AppNavBar extends StatelessWidget {
  final List<NavBarItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  const AppNavBar({super.key, required this.items, required this.index, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: p.border),
          boxShadow: isDark
              ? const []
              : const [BoxShadow(color: Color(0x261E3A78), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItemView(item: items[i], selected: i == index, onTap: () => onSelected(i)),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItemView extends StatelessWidget {
  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavItemView({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected ? primary : p.textSecondary;

    Widget icon = Icon(selected ? item.selectedIcon : item.icon, size: 22, color: color);
    if (item.badge > 0) {
      icon = Badge(label: Text(item.badge > 99 ? '99+' : '${item.badge}'), child: icon);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: selected ? 58 : 34,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? primary.withAlpha(isDark ? 56 : 28) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: icon,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
