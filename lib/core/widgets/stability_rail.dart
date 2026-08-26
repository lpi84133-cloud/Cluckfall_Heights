import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:flutter/material.dart';

/// The delivered three-zone gauge, used as a vertical scale beside the workspace.
///
/// The artwork is the scale and a marker sits alongside it. Showing all three
/// zones at once tells the user how far the current result is from the next
/// state, which a single coloured badge cannot convey. The marker is placed
/// outside the capsule rather than on top of it, so it never hides the zone it
/// is pointing at.
class StabilityRail extends StatelessWidget {
  const StabilityRail({required this.status, this.showLabel = true, this.height = 190, super.key});

  final StabilityStatus status;
  final bool showLabel;
  final double height;

  /// Aspect ratio of the delivered capsule.
  static const double _gaugeAspect = 185 / 600;

  /// Vertical centre of each zone, measured off the artwork rather than assumed
  /// to be equal thirds, because the delivered zones are not evenly sized.
  double get _anchor => switch (status) {
    StabilityStatus.stable => 0.237,
    StabilityStatus.caution => 0.568,
    StabilityStatus.unstable => 0.819,
  };

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color ink = status.ink(palette);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 16,
                child: AnimatedAlign(
                  duration: Motion.slow,
                  curve: Motion.settle,
                  alignment: Alignment(0, _anchor * 2 - 1),
                  child: CustomPaint(
                    size: const Size(11, 16),
                    painter: _MarkerPainter(color: ink),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: height * _gaugeAspect,
                child: Image.asset(IndicatorArt.stabilityGauge, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: Insets.sm),
          Text(status.label.toUpperCase(), style: AppTypography.overline.copyWith(color: ink)),
        ],
      ],
    );
  }
}

/// A right-pointing wedge with softened corners, matching the rounded artwork.
class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, size.height * 0.12)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(0, size.height * 0.88)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_MarkerPainter oldDelegate) => oldDelegate.color != color;
}
