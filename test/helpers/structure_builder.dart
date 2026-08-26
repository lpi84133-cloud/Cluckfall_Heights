import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:cluckfall_heights/domain/structures/structure_type.dart';

/// Terse fixtures for the analysis tests, so each test reads as the layout it
/// describes rather than as a wall of constructor arguments.
PlacedObject item(
  String id, {
  required double weightKg,
  double widthCm = 20,
  double depthCm = 20,
  double heightCm = 20,
  Fragility fragility = Fragility.sturdy,
  LevelSlot slot = LevelSlot.centre,
  ObjectMaterial material = ObjectMaterial.mixed,
  String? name,
}) {
  return PlacedObject(
    id: id,
    sourceObjectId: 'test.$id',
    name: name ?? id,
    widthCm: widthCm,
    depthCm: depthCm,
    heightCm: heightCm,
    weightKg: weightKg,
    fragility: fragility,
    material: material,
    slot: slot,
  );
}

/// Builds a structure from a list of levels given bottom first.
Structure structureOf(
  List<List<PlacedObject>> levelsBottomFirst, {
  double widthCm = 90,
  double heightCm = 180,
  double capacityKg = 25,
  StructureType type = StructureType.shelf,
  String id = 'test.structure',
  String name = 'Test Structure',
}) {
  final int count = levelsBottomFirst.length;
  return Structure(
    id: id,
    name: name,
    type: type,
    widthCm: widthCm,
    depthCm: 30,
    heightCm: heightCm,
    levels: [
      for (int i = 0; i < count; i++)
        StorageLevel(
          id: 'level.$i',
          clearanceCm: heightCm / count,
          capacityKg: capacityKg,
          objects: levelsBottomFirst[i],
        ),
    ],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}
