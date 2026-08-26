import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.accentInk,
      secondary: palette.textPrimary,
      onSecondary: palette.surface,
      error: palette.unstable,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerLowest: palette.canvas,
      surfaceContainerLow: palette.surfaceSunken,
      surfaceContainerHigh: palette.surfaceRaised,
      outline: palette.hairline,
      outlineVariant: palette.hairline,
      shadow: palette.shadow,
    );

    final TextTheme text = AppTypography.textTheme(palette.textPrimary, palette.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      fontFamily: AppFonts.text,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.heading.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.textPrimary, size: 22),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      dividerTheme: DividerThemeData(color: palette.hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: palette.textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Corners.card),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md + 2,
        ),
        hintStyle: AppTypography.body.copyWith(color: palette.textTertiary),
        labelStyle: AppTypography.caption.copyWith(color: palette.textSecondary),
        border: const OutlineInputBorder(borderRadius: Corners.field, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.field,
          borderSide: BorderSide(color: palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.field,
          borderSide: BorderSide(color: palette.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.field,
          borderSide: BorderSide(color: palette.unstable),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? palette.accentInk : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? palette.accent : palette.railTrack,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.railTrack,
        thumbColor: palette.surface,
        overlayColor: palette.accentWash,
        trackHeight: 6,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        showDragHandle: true,
        dragHandleColor: palette.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: AppTypography.caption.copyWith(color: palette.canvas),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Corners.button),
      ),
      // Material's page transition is not the motion this app uses; screens
      // slide in from the right with the app's own curve instead.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
