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
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 19,
    this.dailyReminderMinute = 0,
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
      // Off by default: a notification is something the user opts into, not
      // something that starts firing the moment the app is installed.
      dailyReminderEnabled: json['dailyReminderEnabled'] as bool? ?? false,
      dailyReminderHour: json['dailyReminderHour'] as int? ?? 19,
      dailyReminderMinute: json['dailyReminderMinute'] as int? ?? 0,
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

  /// Whether the single local daily reminder is turned on. This has nothing
  /// to do with push notifications: it is a plain on-device alarm, off by
  /// default, that the user must opt into here.
  final bool dailyReminderEnabled;

  /// Hour of day (0-23) the reminder fires at, in the device's local time.
  final int dailyReminderHour;

  /// Minute of the hour (0-59) the reminder fires at.
  final int dailyReminderMinute;

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
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
  }) {
    return AppPreferences(
      units: units ?? this.units,
      theme: theme ?? this.theme,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
      avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
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
    'dailyReminderEnabled': dailyReminderEnabled,
    'dailyReminderHour': dailyReminderHour,
    'dailyReminderMinute': dailyReminderMinute,
  };
}
