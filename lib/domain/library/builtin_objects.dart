import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';

/// The twelve objects that ship with the app.
///
/// Dimensions and weights are ordinary real-world figures for household items,
/// because the analysis is only as useful as the numbers behind it. Every one of
/// them is editable: the user duplicates an entry and adjusts it, or writes a
/// profile from scratch.
///
/// The chicken, the egg and the coin are sample objects that show what the three
/// interesting cases look like, a bulky light item, a fragile item and a small
/// dense item. They are not characters, rewards or currency.
abstract final class BuiltInObjects {
  static const StorageObject woodenShelf = StorageObject(
    id: 'builtin.wooden_shelf',
    name: 'Wooden Shelf Insert',
    widthCm: 60,
    depthCm: 28,
    heightCm: 4,
    weightKg: 3.2,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.wood,
    category: ObjectCategory.shelving,
    artAsset: ObjectArt.woodenShelf,
    builtIn: true,
    note: 'A spare board used as a divider inside a level.',
  );

  static const StorageObject metalShelf = StorageObject(
    id: 'builtin.metal_shelf',
    name: 'Metal Shelf Insert',
    widthCm: 60,
    depthCm: 30,
    heightCm: 4,
    weightKg: 4.6,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.metal,
    category: ObjectCategory.shelving,
    artAsset: ObjectArt.metalShelf,
    builtIn: true,
    note: 'Heavier than the wooden board and takes more weight.',
  );

  static const StorageObject storageBox = StorageObject(
    id: 'builtin.storage_box',
    name: 'Small Storage Box',
    widthCm: 30,
    depthCm: 22,
    heightCm: 16,
    weightKg: 2.4,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.plastic,
    category: ObjectCategory.containers,
    artAsset: ObjectArt.storageBox,
    builtIn: true,
    note: 'Lidded box, weight assumes it is part filled.',
  );

  static const StorageObject plasticContainer = StorageObject(
    id: 'builtin.plastic_container',
    name: 'Plastic Container',
    widthCm: 38,
    depthCm: 26,
    heightCm: 20,
    weightKg: 4.1,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.plastic,
    category: ObjectCategory.containers,
    artAsset: ObjectArt.plasticContainer,
    builtIn: true,
  );

  static const StorageObject cardboardBox = StorageObject(
    id: 'builtin.cardboard_box',
    name: 'Cardboard Box',
    widthCm: 34,
    depthCm: 26,
    heightCm: 24,
    weightKg: 5.5,
    fragility: Fragility.delicate,
    material: ObjectMaterial.cardboard,
    category: ObjectCategory.containers,
    artAsset: ObjectArt.cardboardBox,
    builtIn: true,
    note: 'Cardboard sags under load, so it counts as delicate.',
  );

  static const StorageObject bottle = StorageObject(
    id: 'builtin.bottle',
    name: 'Bottle',
    widthCm: 9,
    depthCm: 9,
    heightCm: 30,
    weightKg: 1.3,
    fragility: Fragility.fragile,
    material: ObjectMaterial.glass,
    category: ObjectCategory.kitchen,
    artAsset: ObjectArt.bottle,
    builtIn: true,
    note: 'Tall and narrow, so it also needs clearance above.',
  );

  static const StorageObject jar = StorageObject(
    id: 'builtin.jar',
    name: 'Jar',
    widthCm: 11,
    depthCm: 11,
    heightCm: 15,
    weightKg: 0.9,
    fragility: Fragility.fragile,
    material: ObjectMaterial.glass,
    category: ObjectCategory.kitchen,
    artAsset: ObjectArt.jar,
    builtIn: true,
  );

  static const StorageObject book = StorageObject(
    id: 'builtin.book',
    name: 'Book',
    widthCm: 4,
    depthCm: 16,
    heightCm: 24,
    weightKg: 0.7,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.mixed,
    category: ObjectCategory.household,
    artAsset: ObjectArt.book,
    builtIn: true,
    note: 'Stood upright, which is why the width is small.',
  );

  static const StorageObject toolBox = StorageObject(
    id: 'builtin.tool_box',
    name: 'Tool Box',
    widthCm: 42,
    depthCm: 22,
    heightCm: 20,
    weightKg: 9.8,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.metal,
    category: ObjectCategory.tools,
    artAsset: ObjectArt.toolBox,
    builtIn: true,
    note: 'The heaviest item in the library. Belongs low down.',
  );

  static const StorageObject chicken = StorageObject(
    id: 'builtin.chicken',
    name: 'Chicken Figure',
    widthCm: 18,
    depthCm: 12,
    heightCm: 20,
    weightKg: 0.6,
    fragility: Fragility.delicate,
    material: ObjectMaterial.organic,
    category: ObjectCategory.samples,
    artAsset: ObjectArt.chicken,
    builtIn: true,
    note: 'Sample object: takes up room without weighing much.',
  );

  static const StorageObject egg = StorageObject(
    id: 'builtin.egg',
    name: 'Egg',
    widthCm: 5,
    depthCm: 5,
    heightCm: 6,
    weightKg: 0.06,
    fragility: Fragility.fragile,
    material: ObjectMaterial.organic,
    category: ObjectCategory.samples,
    artAsset: ObjectArt.egg,
    builtIn: true,
    note: 'Sample object: shows how the fragile checks behave.',
  );

  static const StorageObject coin = StorageObject(
    id: 'builtin.coin',
    name: 'Coin Roll',
    widthCm: 3,
    depthCm: 3,
    heightCm: 7,
    weightKg: 0.5,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.metal,
    category: ObjectCategory.samples,
    artAsset: ObjectArt.coin,
    builtIn: true,
    note: 'Sample object: small but dense for its size.',
  );

  static const List<StorageObject> all = [
    storageBox,
    plasticContainer,
    cardboardBox,
    woodenShelf,
    metalShelf,
    bottle,
    jar,
    book,
    toolBox,
    chicken,
    egg,
    coin,
  ];

  static StorageObject? byId(String id) {
    for (final StorageObject object in all) {
      if (object.id == id) return object;
    }
    return null;
  }
}
