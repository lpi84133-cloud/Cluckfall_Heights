import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Selectable filter tag, used above the object library and the saved list.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Number of matching items. Shown so the filter tells the user something
  /// before it is even tapped.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onSelected,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(horizontal: Insets.md + 2, vertical: Insets.sm),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
            border: Border.all(color: selected ? palette.accent : palette.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: selected ? palette.accentInk : palette.textSecondary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: AppTypography.numeric.copyWith(
                    fontSize: 12,
                    color: selected
                        ? palette.accentInk.withValues(alpha: 0.6)
                        : palette.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
