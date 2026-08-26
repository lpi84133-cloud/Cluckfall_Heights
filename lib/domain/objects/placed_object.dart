import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:meta/meta.dart';

/// One object sitting on one level of a structure.
///
/// The physical properties are copied out of the [StorageObject] at the moment
/// of placement rather than looked up by id. Editing a library profile later
/// must not silently change the analysis of a structure the user already saved
/// and reviewed, and a deleted profile must not leave a hole in an old layout.
/// [sourceObjectId] is kept only so the artwork and the origin stay traceable.
@immutable
class PlacedObject {
  const PlacedObject({
    required this.id,
    required this.sourceObjectId,
    required this.name,
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    required this.weightKg,
    required this.fragility,
    required this.material,
    this.slot = LevelSlot.centre,
    this.artAsset,
  });

  factory PlacedObject.fromObject(
    StorageObject object, {
    required String id,
    LevelSlot slot = LevelSlot.centre,
    double? weightKg,
  }) {
    return PlacedObject(
      id: id,
      sourceObjectId: object.id,
      name: object.name,
      widthCm: object.widthCm,
      depthCm: object.depthCm,
      heightCm: object.heightCm,
      weightKg: weightKg ?? object.weightKg,
      fragility: object.fragility,
      material: object.material,
      slot: slot,
      artAsset: object.artAsset,
    );
  }

  factory PlacedObject.fromJson(Map<String, dynamic> json) {
    return PlacedObject(
      id: json['id'] as String,
      sourceObjectId: json['sourceObjectId'] as String,
      name: json['name'] as String,
      widthCm: (json['widthCm'] as num).toDouble(),
      depthCm: (json['depthCm'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      fragility: Fragility.fromName(json['fragility'] as String?),
      material: ObjectMaterial.fromName(json['material'] as String?),
      slot: LevelSlot.fromName(json['slot'] as String?),
      artAsset: json['artAsset'] as String?,
    );
  }

  final String id;
  final String sourceObjectId;
  final String name;
  final double widthCm;
  final double depthCm;
  final double heightCm;
  final double weightKg;
  final Fragility fragility;
  final ObjectMaterial material;

  /// Which third of the level the object stands in.
  final LevelSlot slot;

  final String? artAsset;

  PlacedObject copyWith({String? id, double? weightKg, LevelSlot? slot}) {
    return PlacedObject(
      id: id ?? this.id,
      sourceObjectId: sourceObjectId,
      name: name,
      widthCm: widthCm,
      depthCm: depthCm,
      heightCm: heightCm,
      weightKg: weightKg ?? this.weightKg,
      fragility: fragility,
      material: material,
      slot: slot ?? this.slot,
      artAsset: artAsset,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceObjectId': sourceObjectId,
    'name': name,
    'widthCm': widthCm,
    'depthCm': depthCm,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'fragility': fragility.name,
    'material': material.name,
    'slot': slot.name,
    if (artAsset != null) 'artAsset': artAsset,
  };

  @override
  bool operator ==(Object other) => other is PlacedObject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
