import 'package:flutter/material.dart';

/// Two bundled families, each with one job.
///
/// Fraunces is a soft serif used only for headings and for numbers that carry a
/// result, which is what gives the app its own voice instead of the usual
/// single-sans utility look. Manrope handles everything the user reads while
/// working. Both are shipped as static instances, so no weight is synthesised
/// and nothing is fetched at runtime.
abstract final class AppFonts {
  static const String display = 'Fraunces';
  static const String text = 'Manrope';
}

abstract final class AppTypography {
  /// Screen titles.
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.14,
    letterSpacing: -0.6,
  );

  /// Section headings inside a screen.
  static const TextStyle heading = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 21,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// A measured result: total weight, centre of mass offset, level count.
  static const TextStyle metric = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.1,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w500,
    fontSize: 13,
    height: 1.35,
  );

  /// Uppercase micro label used above grouped fields and on the height scale.
  static const TextStyle overline = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.9,
  );

  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Numbers that sit next to each other in a column and must not jitter.
  static const TextStyle numeric = TextStyle(
    fontFamily: AppFonts.text,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: display.copyWith(color: primary),
      displayMedium: display.copyWith(color: primary, fontSize: 26),
      headlineMedium: heading.copyWith(color: primary),
      headlineSmall: metric.copyWith(color: primary),
      titleMedium: title.copyWith(color: primary),
      titleSmall: caption.copyWith(color: secondary),
      bodyLarge: body.copyWith(color: primary),
      bodyMedium: body.copyWith(color: primary),
      bodySmall: caption.copyWith(color: secondary),
      labelLarge: button.copyWith(color: primary),
      labelMedium: numeric.copyWith(color: primary),
      labelSmall: overline.copyWith(color: secondary),
    );
  }
}
