import 'package:flutter/material.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Friendly message for "nothing here" and "could not load" situations.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 20 : 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 52 : 68,
                height: compact ? 52 : 68,
                decoration: BoxDecoration(color: accent.withAlpha(26), shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 26 : 32, color: accent),
              ),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.35, color: p.textSecondary)),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact one-line notice (connection problems, retry prompts).
class NoticeBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onRetry;
  final bool retrying;

  const NoticeBanner({
    super.key,
    required this.message,
    this.icon = Icons.cloud_off_rounded,
    this.color = AppColors.error,
    this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = readableOn(context, color);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 6, onRetry == null ? 12 : 4, 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.3, color: fg)),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: retrying ? null : onRetry,
              style: TextButton.styleFrom(foregroundColor: fg, visualDensity: VisualDensity.compact),
              child: retrying
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder box shown while data loads.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.55 + 0.45 * _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: p.skeleton, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

/// Placeholder shaped like a list card.
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(width: 40, height: 40, radius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Skeleton(width: 120, height: 14), SizedBox(height: 8), Skeleton(width: 80, height: 11)],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Skeleton(height: 12),
          SizedBox(height: 8),
          Skeleton(width: 180, height: 12),
        ],
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  final int count;
  const ListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          const CardSkeleton(),
          if (i < count - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class StatGridSkeleton extends StatelessWidget {
  const StatGridSkeleton({super.key});

  Widget _tile() => const AppCard(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 38, height: 38, radius: 12),
            SizedBox(height: 14),
            Skeleton(width: 56, height: 26),
            SizedBox(height: 8),
            Skeleton(width: 90, height: 12),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [Expanded(child: _tile()), const SizedBox(width: 12), Expanded(child: _tile())]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _tile()), const SizedBox(width: 12), Expanded(child: _tile())]),
      ],
    );
  }
}

/// Dot + label showing the state of the live connection.
class ConnectionPill extends StatelessWidget {
  final LiveStatus status;
  const ConnectionPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case LiveStatus.connected:
        color = AppColors.success;
        label = 'Connected';
        break;
      case LiveStatus.connecting:
        color = AppColors.warning;
        label = 'Connecting';
        break;
      case LiveStatus.offline:
        color = AppColors.error;
        label = 'Offline';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: readableOn(context, color))),
        ],
      ),
    );
  }
}
