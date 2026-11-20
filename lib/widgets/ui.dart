import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded surface with a hairline border and a soft shadow (no shadow in dark mode).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: p.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A colored icon on a softly tinted rounded square.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge({super.key, required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Round 40 px button used in the header and on top of the map.
class CircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final bool elevated;

  const CircleIconButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.size = 40,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final button = DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
        boxShadow: elevated
            ? const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: size, height: size, child: Center(child: child)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Selectable pill used for filters.
class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = color ?? Theme.of(context).colorScheme.primary;
    final fg = selected ? readableOn(context, accent) : p.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? accent.withAlpha(30) : p.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: selected ? accent : p.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg.withAlpha(190))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title with an optional "View all" style action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Centers content and limits its width on tablets and landscape phones.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Linear progress with rounded ends.
class AppProgress extends StatelessWidget {
  final double value;
  final Color color;
  final double height;

  const AppProgress({super.key, required this.value, required this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        color: color,
        backgroundColor: p.surfaceAlt,
      ),
    );
  }
}

/// Small colored dot, optionally followed by a label and a count.
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int? count;

  const LegendItem({super.key, required this.color, required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary)),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}


/// Pill-shaped segmented tabs (Overview / Maintenance / Alerts).
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentTabs({super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.control - 4),
                    boxShadow: i == index
                        ? [BoxShadow(color: scheme.primary.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: i == index ? scheme.onPrimary : p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Square shortcut tile: icon on top, label below, optional count badge.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final int badge;

  const QuickAction({super.key, required this.icon, required this.label, this.onTap, this.color, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    Widget i = Icon(icon, size: 26, color: c);
    if (badge > 0) {
      i = Badge(label: Text(badge > 99 ? '99+' : '$badge'), child: i);
    }
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          i,
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
