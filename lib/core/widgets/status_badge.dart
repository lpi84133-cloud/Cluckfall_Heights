import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:flutter/material.dart';

/// Colour lookup for a stability status, so every surface agrees.
extension StabilityStatusColors on StabilityStatus {
  Color ink(AppPalette palette) => switch (this) {
    StabilityStatus.stable => palette.stable,
    StabilityStatus.caution => palette.caution,
    StabilityStatus.unstable => palette.unstable,
  };

  Color wash(AppPalette palette) => switch (this) {
    StabilityStatus.stable => palette.stableWash,
    StabilityStatus.caution => palette.cautionWash,
    StabilityStatus.unstable => palette.unstableWash,
  };
}

/// Compact status marker.
///
/// The dot is drawn rather than taken from the gauge artwork: at this size the
/// rendered capsule turns to mush, and a flat dot in the exact sampled colour
/// stays legible and matches the gauge sitting elsewhere on the screen.
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, this.compact = false, super.key});

  final StabilityStatus status;

  /// Dot only, no label. For dense lists where the row already names the item.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color ink = status.ink(palette);

    final Widget dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: ink,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: ink.withValues(alpha: 0.35), blurRadius: 6)],
      ),
    );

    if (compact) {
      return Semantics(label: status.label, child: dot);
    }

    return Semantics(
      label: 'Stability ${status.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: status.wash(palette),
          borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              const SizedBox(width: Insets.sm),
              Text(status.label, style: AppTypography.caption.copyWith(color: ink)),
            ],
          ),
        ),
      ),
    );
  }
}
