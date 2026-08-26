import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure_type.dart';
import 'package:meta/meta.dart';

/// A saved storage plan: the frame, its levels, and everything placed on them.
@immutable
class Structure {
  const Structure({
    required this.id,
    required this.name,
    required this.type,
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    required this.levels,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A new structure with evenly spaced levels sized from the chosen type.
  factory Structure.blank({
    required String id,
    required String name,
    required StructureType type,
    required List<String> levelIds,
    required DateTime now,
    double? widthCm,
    double? depthCm,
    double? heightCm,
  }) {
    final ({double width, double depth, double height, int levels}) preset = type.defaults;
    final double width = widthCm ?? preset.width;
    final double height = heightCm ?? preset.height;
    final int count = levelIds.length;

    return Structure(
      id: id,
      name: name,
      type: type,
      widthCm: width,
      depthCm: depthCm ?? preset.depth,
      heightCm: height,
      levels: [
        for (final String levelId in levelIds)
          StorageLevel(
            id: levelId,
            clearanceCm: count == 0 ? height : height / count,
            capacityKg: defaultCapacityFor(type, width),
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Structure.fromJson(Map<String, dynamic> json) {
    return Structure(
      id: json['id'] as String,
      name: json['name'] as String,
      type: StructureType.fromName(json['type'] as String?),
      widthCm: (json['widthCm'] as num).toDouble(),
      depthCm: (json['depthCm'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .map((e) => StorageLevel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String name;
  final StructureType type;
  final double widthCm;
  final double depthCm;
  final double heightCm;

  /// Bottom to top. Index 0 is the lowest level.
  final List<StorageLevel> levels;

  final DateTime createdAt;
  final DateTime updatedAt;

  static double defaultCapacityFor(StructureType type, double widthCm) =>
      (widthCm * type.loadPerCmWidth).clamp(4.0, 120.0);

  int get objectCount => levels.fold(0, (sum, l) => sum + l.objects.length);

  double get totalWeightKg => levels.fold(0, (sum, l) => sum + l.loadKg);

  bool get isEmpty => objectCount == 0;

  Iterable<PlacedObject> get allObjects => levels.expand((l) => l.objects);

  /// Height of the base of a level above the floor of the structure.
  double baseHeightOf(int levelIndex) {
    double height = 0;
    for (int i = 0; i < levelIndex && i < levels.length; i++) {
      height += levels[i].clearanceCm;
    }
    return height;
  }

  int? levelIndexOfObject(String objectId) {
    for (int i = 0; i < levels.length; i++) {
      if (levels[i].objects.any((o) => o.id == objectId)) return i;
    }
    return null;
  }

  Structure copyWith({
    String? name,
    StructureType? type,
    double? widthCm,
    double? depthCm,
    double? heightCm,
    List<StorageLevel>? levels,
    DateTime? updatedAt,
  }) {
    return Structure(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      widthCm: widthCm ?? this.widthCm,
      depthCm: depthCm ?? this.depthCm,
      heightCm: heightCm ?? this.heightCm,
      levels: levels ?? this.levels,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Structure withLevelReplaced(int index, StorageLevel level) {
    final List<StorageLevel> next = [...levels];
    next[index] = level;
    return copyWith(levels: next);
  }

  /// Moves an object to the end of another level, keeping everything else as is.
  Structure withObjectMoved(String objectId, int toLevelIndex) {
    final int? from = levelIndexOfObject(objectId);
    if (from == null || from == toLevelIndex) return this;
    if (toLevelIndex < 0 || toLevelIndex >= levels.length) return this;

    final PlacedObject object = levels[from].objects.firstWhere((o) => o.id == objectId);
    final List<StorageLevel> next = [...levels];
    next[from] = next[from].withObjectRemoved(objectId);
    next[toLevelIndex] = next[toLevelIndex].withObjectAdded(object);
    return copyWith(levels: next);
  }

  /// Moves an object sideways within its own level.
  Structure withObjectSlotChanged(String objectId, LevelSlot slot) {
    final int? index = levelIndexOfObject(objectId);
    if (index == null) return this;

    final List<StorageLevel> next = [...levels];
    next[index] = next[index].copyWith(
      objects: next[index].objects
          .map((o) => o.id == objectId ? o.copyWith(slot: slot) : o)
          .toList(growable: false),
    );
    return copyWith(levels: next);
  }

  /// Swaps two objects between their levels. Used by the rearrangement planner
  /// when a straight move would just overload the destination.
  Structure withObjectsSwapped(String firstId, String secondId) {
    final int? firstLevel = levelIndexOfObject(firstId);
    final int? secondLevel = levelIndexOfObject(secondId);
    if (firstLevel == null || secondLevel == null || firstLevel == secondLevel) return this;

    final PlacedObject first = levels[firstLevel].objects.firstWhere((o) => o.id == firstId);
    final PlacedObject second = levels[secondLevel].objects.firstWhere((o) => o.id == secondId);

    final List<StorageLevel> next = [...levels];
    next[firstLevel] = next[firstLevel].copyWith(
      objects: next[firstLevel].objects.map((o) => o.id == firstId ? second : o).toList(
        growable: false,
      ),
    );
    next[secondLevel] = next[secondLevel].copyWith(
      objects: next[secondLevel].objects.map((o) => o.id == secondId ? first : o).toList(
        growable: false,
      ),
    );
    return copyWith(levels: next);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'widthCm': widthCm,
    'depthCm': depthCm,
    'heightCm': heightCm,
    'levels': levels.map((l) => l.toJson()).toList(growable: false),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) => other is Structure && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
