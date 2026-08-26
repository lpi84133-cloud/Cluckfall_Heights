import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:meta/meta.dart';

enum AppThemeChoice {
  system,
  light,
  dark;

  String get label => switch (this) {
    AppThemeChoice.system => 'Match system',
    AppThemeChoice.light => 'Light',
    AppThemeChoice.dark => 'Dark',
  };

  static AppThemeChoice fromName(String? name) => AppThemeChoice.values.firstWhere(
    (c) => c.name == name,
    orElse: () => AppThemeChoice.system,
  );
}

/// Everything the user can configure, in one value object.
///
/// Stored locally and never sent anywhere. The display name and photo exist so
/// the profile screen can show whose plans these are on a shared device; both are
/// optional and neither is required to use the app.
@immutable
class AppPreferences {
  const AppPreferences({
    this.units = MeasurementSystem.metric,
    this.theme = AppThemeChoice.system,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.onboardingCompleted = false,
    this.displayName,
    this.avatarPath,
  });

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    return AppPreferences(
      units: json['units'] == MeasurementSystem.imperial.name
          ? MeasurementSystem.imperial
          : MeasurementSystem.metric,
      theme: AppThemeChoice.fromName(json['theme'] as String?),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      displayName: json['displayName'] as String?,
      avatarPath: json['avatarPath'] as String?,
    );
  }

  final MeasurementSystem units;
  final AppThemeChoice theme;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool onboardingCompleted;
  final String? displayName;

  /// Absolute path to the cropped photo inside the app's private directory.
  final String? avatarPath;

  bool get hasAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  /// Initials for the placeholder shown when there is no photo.
  String get initials {
    final List<String> parts = (displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  AppPreferences copyWith({
    MeasurementSystem? units,
    AppThemeChoice? theme,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? onboardingCompleted,
    String? displayName,
    String? avatarPath,
    bool clearAvatar = false,
    bool clearDisplayName = false,
  }) {
    return AppPreferences(
      units: units ?? this.units,
      theme: theme ?? this.theme,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'units': units.name,
    'theme': theme.name,
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'onboardingCompleted': onboardingCompleted,
    if (displayName != null) 'displayName': displayName,
    if (avatarPath != null) 'avatarPath': avatarPath,
  };
}
