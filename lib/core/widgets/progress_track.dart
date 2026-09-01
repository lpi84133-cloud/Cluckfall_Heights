import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Horizontal progress, filling strictly left to right.
///
/// Deliberately not [LinearProgressIndicator]: this needs the app's own track
/// colour, a bright leading edge so the eye can find the current position, and
/// no indeterminate mode at all. Progress here always reflects real work, so
/// there is never anything to fake.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    required this.value,
    this.thickness = 10,
    this.showLeadingEdge = true,
    super.key,
  });

  /// Clamped to 0..1 by the widget, so callers cannot overshoot.
  final double value;
  final double thickness;

  /// A slightly brighter cap at the filled end.
  final bool showLeadingEdge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double fraction = value.clamp(0.0, 1.0);

    return Semantics(
      value: '${(fraction * 100).round()}%',
      child: SizedBox(
        height: thickness,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.railTrack,
            borderRadius: BorderRadius.all(Radius.circular(thickness)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(thickness)),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: fraction),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              builder: (context, animated, _) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.shelfEdge, palette.accent],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical progress, filling bottom to top.
///
/// Styled as an upright of a shelf frame with rungs, which is why the app can
/// show progress vertically without it reading as a stray scrollbar.
class VerticalProgressTrack extends StatelessWidget {
  const VerticalProgressTrack({
    required this.value,
    this.thickness = 8,
    this.rungs = 9,
    super.key,
  });

  final double value;
  final double thickness;

  /// Tick marks along the upright. They give the fill a sense of distance
  /// travelled instead of a featureless bar.
  final int rungs;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double fraction = value.clamp(0.0, 1.0);

    return Semantics(
      value: '${(fraction * 100).round()}%',
      child: SizedBox(
        width: thickness,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double filled = constraints.maxHeight * fraction;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: palette.railTrack,
                borderRadius: BorderRadius.all(Radius.circular(thickness)),
              ),
              child: Stack(
                children: [
                  for (int i = 1; i < rungs; i++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: constraints.maxHeight * i / rungs,
                      height: 1,
                      child: ColoredBox(color: palette.hairline.withValues(alpha: 0.7)),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: filled,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(thickness)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [palette.shelfEdge, palette.accent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
