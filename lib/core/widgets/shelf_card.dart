import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:flutter/material.dart';

/// The container every list row and panel in the app is built from.
///
/// It is not a plain rounded rectangle. A vertical upright runs down the left
/// edge and an amber trim line sits along the bottom, so a column of these
/// reads as boards seated into a frame. That motif is what ties the interface to
/// what the app actually does, and it removes the need for the usual leading
/// icon in a circle on every row.
class ShelfCard extends StatelessWidget {
  const ShelfCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.accent,
    this.showTrim = true,
    this.raised = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Colour of the left upright. Defaults to a neutral hairline; screens pass a
  /// status colour when the row carries a stability result.
  final Color? accent;

  /// The amber line along the bottom edge. Turned off for nested cards, where
  /// repeating it would be noise.
  final bool showTrim;

  final bool raised;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color upright = accent ?? palette.hairline;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: raised ? palette.surfaceRaised : palette.surface,
        borderRadius: Corners.card,
        border: Border.all(color: palette.hairline),
        boxShadow: raised ? Elevations.lifted(palette) : Elevations.card(palette),
      ),
      child: ClipRRect(
        borderRadius: Corners.card,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: palette.accentWash.withValues(alpha: 0.5),
            highlightColor: palette.accentWash.withValues(alpha: 0.3),
            child: Stack(
              children: [
                Padding(
                  padding: padding.add(const EdgeInsets.only(left: Insets.xs)),
                  child: child,
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(color: upright),
                ),
                if (showTrim)
                  Positioned(
                    left: 4,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: ColoredBox(color: palette.shelfEdge.withValues(alpha: 0.55)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
