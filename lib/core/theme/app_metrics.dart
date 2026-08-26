import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Spacing, radii and elevation, kept in one scale so screens stay in rhythm.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  /// Horizontal page margin. Wider than the Material default so the vertical
  /// height scale on the left has room to breathe.
  static const double page = 20;
}

/// Corner radii.
///
/// Cards use an intentionally asymmetric shape: square at the top left, rounded
/// elsewhere. It reads as a shelf board seated into an upright, which is the
/// visual motif the whole app is built on, and it keeps the layout from looking
/// like the usual grid of evenly rounded rectangles.
abstract final class Corners {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xxl = 26;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.only(
    topLeft: Radius.circular(xs),
    topRight: Radius.circular(lg),
    bottomRight: Radius.circular(lg),
    bottomLeft: Radius.circular(lg),
  );

  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xxl));

  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
}

abstract final class Elevations {
  /// Resting shadow for cards. Warm and wide rather than dark and tight.
  static List<BoxShadow> card(AppPalette palette) => [
    BoxShadow(color: palette.shadow, blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -4),
  ];

  /// Floating elements: the navigation dock, dragged objects.
  static List<BoxShadow> lifted(AppPalette palette) => [
    BoxShadow(color: palette.shadow, blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -6),
  ];
}

abstract final class Motion {
  /// Short enough to feel instant, long enough to be readable.
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve settle = Curves.easeOutBack;
}
