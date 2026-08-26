import 'package:flutter/material.dart';

/// Raw palette.
///
/// The status colours and the material accents are sampled from the delivered
/// artwork (see `tools/assets_report.json`) so painted UI sits flush against the
/// rendered objects instead of clashing with them.
abstract final class Palette {
  // Neutrals, warm rather than grey, matching the cream plates in the artwork.
  static const Color milk = Color(0xFFFBF7EF);
  static const Color cream = Color(0xFFF4EADA);
  static const Color creamDeep = Color(0xFFEADFC9);
  static const Color beige = Color(0xFFE0D0B2);
  static const Color sand = Color(0xFFCDBB9B);

  static const Color graphite = Color(0xFF34373C);
  static const Color graphiteSoft = Color(0xFF4A4E55);
  static const Color slate = Color(0xFF6C7179);
  static const Color mist = Color(0xFFA9AEB5);

  // Signature accent, taken from the shelf trim and the coin.
  static const Color amber = Color(0xFFF2B824);
  static const Color amberDeep = Color(0xFFD8A830);
  static const Color amberSoft = Color(0xFFFBE7B4);

  // Status, sampled straight off the delivered stability gauge.
  static const Color stable = Color(0xFF93CE36);
  static const Color caution = Color(0xFFFDC20D);
  static const Color unstable = Color(0xFFFF8408);

  // Muted status fills for large surfaces, where the raw gauge colours shout.
  static const Color stableMuted = Color(0xFFEDF5DC);
  static const Color cautionMuted = Color(0xFFFDF2D6);
  static const Color unstableMuted = Color(0xFFFDE7D3);

  // Materials referenced by the object library.
  static const Color wood = Color(0xFFC07830);
  static const Color metal = Color(0xFF787878);

  // Dark theme greys, kept slightly warm so the cream artwork does not look
  // out of place on top of them.
  static const Color night = Color(0xFF1A1B1E);
  static const Color nightRaised = Color(0xFF24262A);
  static const Color nightEdge = Color(0xFF32353A);
  static const Color nightText = Color(0xFFF3EEE4);
}

/// Semantic colours that Material's [ColorScheme] has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentInk,
    required this.accentWash,
    required this.stable,
    required this.caution,
    required this.unstable,
    required this.stableWash,
    required this.cautionWash,
    required this.unstableWash,
    required this.shelfEdge,
    required this.railTrack,
    required this.shadow,
  });

  /// Page background, behind everything.
  final Color canvas;

  /// Default card and sheet fill.
  final Color surface;

  /// A card lifted above another card.
  final Color surfaceRaised;

  /// Recessed areas: input wells, gauge tracks, shelf interiors.
  final Color surfaceSunken;

  /// One-pixel dividers and card outlines.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Signature amber used for primary actions and the shelf trim.
  final Color accent;

  /// Text and icons drawn on top of [accent].
  final Color accentInk;

  /// Faint amber tint for selected states.
  final Color accentWash;

  final Color stable;
  final Color caution;
  final Color unstable;

  final Color stableWash;
  final Color cautionWash;
  final Color unstableWash;

  /// The thin trim line that reads as the front edge of a shelf.
  final Color shelfEdge;

  /// Empty part of any progress or load track.
  final Color railTrack;

  /// Warm shadow tint. Neutral black shadows look dirty over cream.
  final Color shadow;

  static const AppPalette light = AppPalette(
    canvas: Palette.milk,
    surface: Colors.white,
    surfaceRaised: Colors.white,
    surfaceSunken: Palette.cream,
    hairline: Palette.creamDeep,
    textPrimary: Palette.graphite,
    textSecondary: Palette.slate,
    textTertiary: Palette.mist,
    accent: Palette.amber,
    accentInk: Palette.graphite,
    accentWash: Palette.amberSoft,
    stable: Color(0xFF6FA828),
    caution: Color(0xFFCF9A05),
    unstable: Color(0xFFE06C00),
    stableWash: Palette.stableMuted,
    cautionWash: Palette.cautionMuted,
    unstableWash: Palette.unstableMuted,
    shelfEdge: Palette.amberDeep,
    railTrack: Palette.creamDeep,
    shadow: Color(0x1A5A4A2E),
  );

  static const AppPalette dark = AppPalette(
    canvas: Palette.night,
    surface: Palette.nightRaised,
    surfaceRaised: Palette.nightEdge,
    surfaceSunken: Color(0xFF15171A),
    hairline: Color(0xFF3B3E44),
    textPrimary: Palette.nightText,
    textSecondary: Color(0xFFAFB4BB),
    textTertiary: Color(0xFF767B82),
    accent: Palette.amber,
    accentInk: Palette.graphite,
    accentWash: Color(0xFF3A3220),
    stable: Palette.stable,
    caution: Palette.caution,
    unstable: Palette.unstable,
    stableWash: Color(0xFF25301A),
    cautionWash: Color(0xFF342C13),
    unstableWash: Color(0xFF35240F),
    shelfEdge: Palette.amberDeep,
    railTrack: Color(0xFF2E3136),
    shadow: Color(0x66000000),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentInk,
    Color? accentWash,
    Color? stable,
    Color? caution,
    Color? unstable,
    Color? stableWash,
    Color? cautionWash,
    Color? unstableWash,
    Color? shelfEdge,
    Color? railTrack,
    Color? shadow,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentWash: accentWash ?? this.accentWash,
      stable: stable ?? this.stable,
      caution: caution ?? this.caution,
      unstable: unstable ?? this.unstable,
      stableWash: stableWash ?? this.stableWash,
      cautionWash: cautionWash ?? this.cautionWash,
      unstableWash: unstableWash ?? this.unstableWash,
      shelfEdge: shelfEdge ?? this.shelfEdge,
      railTrack: railTrack ?? this.railTrack,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      hairline: mix(hairline, other.hairline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      accent: mix(accent, other.accent),
      accentInk: mix(accentInk, other.accentInk),
      accentWash: mix(accentWash, other.accentWash),
      stable: mix(stable, other.stable),
      caution: mix(caution, other.caution),
      unstable: mix(unstable, other.unstable),
      stableWash: mix(stableWash, other.stableWash),
      cautionWash: mix(cautionWash, other.cautionWash),
      unstableWash: mix(unstableWash, other.unstableWash),
      shelfEdge: mix(shelfEdge, other.shelfEdge),
      railTrack: mix(railTrack, other.railTrack),
      shadow: mix(shadow, other.shadow),
    );
  }

  /// Neutral fill for a user-defined object that has no artwork.
  Color get sandTone => Palette.sand;
}

/// Shorthand for reaching the palette from a widget.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
