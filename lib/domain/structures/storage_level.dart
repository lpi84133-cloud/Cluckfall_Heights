import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:meta/meta.dart';

/// One shelf board, drawer or tier inside a structure.
///
/// Levels are ordered bottom to top: index 0 is the lowest. Every calculation in
/// the analysis relies on that, because height above the base is what makes a
/// layout top-heavy.
@immutable
class StorageLevel {
  const StorageLevel({
    required this.id,
    required this.clearanceCm,
    required this.capacityKg,
    this.objects = const [],
    this.label,
  });

  factory StorageLevel.fromJson(Map<String, dynamic> json) {
    return StorageLevel(
      id: json['id'] as String,
      clearanceCm: (json['clearanceCm'] as num).toDouble(),
      capacityKg: (json['capacityKg'] as num).toDouble(),
      objects: (json['objects'] as List<dynamic>? ?? const [])
          .map((e) => PlacedObject.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      label: json['label'] as String?,
    );
  }

  final String id;

  /// Vertical space between this board and the one above it.
  final double clearanceCm;

  /// What this level is assumed to hold safely. Editable per level.
  final double capacityKg;

  /// Left to right order as placed by the user.
  final List<PlacedObject> objects;

  /// Optional user name, for example "Jars" or "Winter gear".
  final String? label;

  double get loadKg => objects.fold(0, (sum, o) => sum + o.weightKg);

  double get usedWidthCm => objects.fold(0, (sum, o) => sum + o.widthCm);

  /// Fraction of the assumed capacity in use. Above 1 the level is overloaded.
  double get capacityUse => capacityKg <= 0 ? 0 : loadKg / capacityKg;

  bool get isEmpty => objects.isEmpty;

  double get tallestObjectCm =>
      objects.isEmpty ? 0 : objects.map((o) => o.heightCm).reduce((a, b) => a > b ? a : b);

  StorageLevel copyWith({
    double? clearanceCm,
    double? capacityKg,
    List<PlacedObject>? objects,
    String? label,
  }) {
    return StorageLevel(
      id: id,
      clearanceCm: clearanceCm ?? this.clearanceCm,
      capacityKg: capacityKg ?? this.capacityKg,
      objects: objects ?? this.objects,
      label: label ?? this.label,
    );
  }

  StorageLevel withObjectAdded(PlacedObject object) =>
      copyWith(objects: [...objects, object]);

  StorageLevel withObjectRemoved(String objectId) =>
      copyWith(objects: objects.where((o) => o.id != objectId).toList(growable: false));

  Map<String, dynamic> toJson() => {
    'id': id,
    'clearanceCm': clearanceCm,
    'capacityKg': capacityKg,
    'objects': objects.map((o) => o.toJson()).toList(growable: false),
    if (label != null) 'label': label,
  };
}
