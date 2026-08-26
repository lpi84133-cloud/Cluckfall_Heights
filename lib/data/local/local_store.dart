import 'package:hive_ce_flutter/hive_flutter.dart';

/// Names of the on-device boxes. Kept together so a rename cannot miss a caller.
abstract final class BoxNames {
  static const String structures = 'structures';
  static const String objectProfiles = 'object_profiles';
  static const String preferences = 'preferences';
}

/// Opens and holds the local boxes.
///
/// Records are stored as plain JSON maps rather than through generated binary
/// adapters. The data is small, and a readable format means a schema change is an
/// ordinary migration over maps instead of a regenerated adapter with a type id
/// that must never be reused. It is also what makes export and import possible
/// without a second serialisation path.
class LocalStore {
  LocalStore._({
    required this.structures,
    required this.objectProfiles,
    required this.preferences,
  });

  static Future<LocalStore> open() async {
    await Hive.initFlutter('cluckfall_heights');
    final List<Box<dynamic>> boxes = await Future.wait([
      Hive.openBox<dynamic>(BoxNames.structures),
      Hive.openBox<dynamic>(BoxNames.objectProfiles),
      Hive.openBox<dynamic>(BoxNames.preferences),
    ]);

    return LocalStore._(
      structures: boxes[0],
      objectProfiles: boxes[1],
      preferences: boxes[2],
    );
  }

  final Box<dynamic> structures;
  final Box<dynamic> objectProfiles;
  final Box<dynamic> preferences;

  Future<void> close() => Hive.close();

  /// Hive hands nested maps back as `Map<dynamic, dynamic>`, which the model
  /// constructors cannot cast. This normalises a whole record in one pass.
  static Map<String, dynamic> asJson(Object? raw) {
    final Object? converted = _convert(raw);
    return converted is Map<String, dynamic> ? converted : <String, dynamic>{};
  }

  static Object? _convert(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): _convert(entry.value),
      };
    }
    if (value is List) {
      return value.map(_convert).toList(growable: false);
    }
    return value;
  }
}
