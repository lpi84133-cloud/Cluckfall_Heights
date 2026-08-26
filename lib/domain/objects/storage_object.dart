import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:meta/meta.dart';

/// A reusable object definition, either shipped with the app or written by the
/// user on the Object Editor screen.
///
/// Dimensions are centimetres and weight is kilograms, always. See
/// [MeasurementSystem] for why display units never reach the model.
@immutable
class StorageObject {
  const StorageObject({
    required this.id,
    required this.name,
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    required this.weightKg,
    required this.fragility,
    required this.material,
    required this.category,
    this.artAsset,
    this.builtIn = false,
    this.note,
  });

  factory StorageObject.fromJson(Map<String, dynamic> json) {
    return StorageObject(
      id: json['id'] as String,
      name: json['name'] as String,
      widthCm: (json['widthCm'] as num).toDouble(),
      depthCm: (json['depthCm'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      fragility: Fragility.fromName(json['fragility'] as String?),
      material: ObjectMaterial.fromName(json['material'] as String?),
      category: ObjectCategory.fromName(json['category'] as String?),
      artAsset: json['artAsset'] as String?,
      builtIn: json['builtIn'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  final String id;
  final String name;
  final double widthCm;
  final double depthCm;
  final double heightCm;
  final double weightKg;
  final Fragility fragility;
  final ObjectMaterial material;
  final ObjectCategory category;

  /// Path to the rendered artwork. Null for user-created objects, which are
  /// drawn as a proportional block instead.
  final String? artAsset;

  /// Built-in objects cannot be deleted, only duplicated and edited as a copy.
  final bool builtIn;

  final String? note;

  double get footprintCm2 => widthCm * depthCm;

  /// Kilograms per litre of bounding volume. A high value means the object is
  /// dense for its size, which matters when deciding what belongs low down.
  double get density {
    final double litres = widthCm * depthCm * heightCm / 1000;
    return litres <= 0 ? 0 : weightKg / litres;
  }

  StorageObject copyWith({
    String? id,
    String? name,
    double? widthCm,
    double? depthCm,
    double? heightCm,
    double? weightKg,
    Fragility? fragility,
    ObjectMaterial? material,
    ObjectCategory? category,
    String? artAsset,
    bool? builtIn,
    String? note,
  }) {
    return StorageObject(
      id: id ?? this.id,
      name: name ?? this.name,
      widthCm: widthCm ?? this.widthCm,
      depthCm: depthCm ?? this.depthCm,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      fragility: fragility ?? this.fragility,
      material: material ?? this.material,
      category: category ?? this.category,
      artAsset: artAsset ?? this.artAsset,
      builtIn: builtIn ?? this.builtIn,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'widthCm': widthCm,
    'depthCm': depthCm,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'fragility': fragility.name,
    'material': material.name,
    'category': category.name,
    if (artAsset != null) 'artAsset': artAsset,
    'builtIn': builtIn,
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) => other is StorageObject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
