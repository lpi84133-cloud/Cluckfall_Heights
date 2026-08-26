import 'dart:convert';

import 'package:cluckfall_heights/data/repositories/object_profile_repository.dart';
import 'package:cluckfall_heights/data/repositories/preferences_repository.dart';
import 'package:cluckfall_heights/data/repositories/structure_repository.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:meta/meta.dart';

@immutable
class ImportResult {
  const ImportResult({required this.structures, required this.objects});

  final int structures;
  final int objects;

  bool get isEmpty => structures == 0 && objects == 0;
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Writes and reads the user's own copy of their data.
///
/// This exists because everything lives on one device: without a way to take the
/// data out, moving to a new phone would mean starting over. The format is plain
/// readable JSON that the user owns, not an opaque blob.
class BackupService {
  const BackupService({
    required StructureRepository structures,
    required ObjectProfileRepository objects,
    required PreferencesRepository preferences,
  }) : _structures = structures,
       _objects = objects,
       _preferences = preferences;


  /// Bumped only when the shape changes in a way older builds cannot read.
  static const int formatVersion = 1;

  final StructureRepository _structures;
  final ObjectProfileRepository _objects;
  final PreferencesRepository _preferences;

  String export({required DateTime now}) {
    final AppPreferences preferences = _preferences.read();

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'cluckfall-heights-backup',
      'version': formatVersion,
      'exportedAt': now.toIso8601String(),
      'structures': _structures.all().map((s) => s.toJson()).toList(growable: false),
      'objectProfiles': _objects.custom().map((o) => o.toJson()).toList(growable: false),
      // The photo lives outside the JSON, so the path would not resolve on
      // another device. Everything else round-trips.
      'preferences': preferences.copyWith(clearAvatar: true).toJson(),
    });
  }

  /// Merges a backup into the current data, replacing records with the same id.
  Future<ImportResult> import(String source, {bool restorePreferences = false}) async {
    final Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(jsonDecode(source) as Map);
    } on Object {
      throw const BackupFormatException('This file is not a Cluckfall Heights backup.');
    }

    if (json['format'] != 'cluckfall-heights-backup') {
      throw const BackupFormatException('This file is not a Cluckfall Heights backup.');
    }
    final int version = (json['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. Update the app, then try again.',
      );
    }

    int structureCount = 0;
    int objectCount = 0;

    try {
      for (final Object? raw in json['structures'] as List<dynamic>? ?? const []) {
        final Structure structure = Structure.fromJson(Map<String, dynamic>.from(raw! as Map));
        await _structures.save(structure);
        structureCount++;
      }
      for (final Object? raw in json['objectProfiles'] as List<dynamic>? ?? const []) {
        final StorageObject object = StorageObject.fromJson(
          Map<String, dynamic>.from(raw! as Map),
        );
        await _objects.save(object);
        objectCount++;
      }
    } on Object {
      throw const BackupFormatException('This backup is damaged and could not be read fully.');
    }

    if (restorePreferences && json['preferences'] is Map) {
      final AppPreferences restored = AppPreferences.fromJson(
        Map<String, dynamic>.from(json['preferences'] as Map),
      );
      final AppPreferences current = _preferences.read();
      await _preferences.write(
        restored.copyWith(
          avatarPath: current.avatarPath,
          onboardingCompleted: current.onboardingCompleted,
        ),
      );
    }

    return ImportResult(structures: structureCount, objects: objectCount);
  }

  /// Clears every box. Onboarding is left marked as done, because someone who has
  /// used the app enough to reset it does not need the introduction again.
  Future<void> resetEverything() async {
    await _structures.deleteAll();
    await _objects.deleteAll();
    await _preferences.write(const AppPreferences(onboardingCompleted: true));
  }
}
