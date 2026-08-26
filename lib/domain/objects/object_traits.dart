/// How much care an object needs.
///
/// Three levels rather than a boolean, because the analysis treats them
/// differently: a moderately delicate item under something heavy is worth a
/// warning, while a genuinely fragile one is a problem.
enum Fragility {
  sturdy,
  delicate,
  fragile;

  String get label => switch (this) {
    Fragility.sturdy => 'Sturdy',
    Fragility.delicate => 'Delicate',
    Fragility.fragile => 'Fragile',
  };

  String get description => switch (this) {
    Fragility.sturdy => 'Takes weight on top without trouble.',
    Fragility.delicate => 'Should not carry heavy items.',
    Fragility.fragile => 'Keep clear of anything heavy above it.',
  };

  bool get needsProtection => this != Fragility.sturdy;

  static Fragility fromName(String? name) =>
      Fragility.values.firstWhere((f) => f.name == name, orElse: () => Fragility.sturdy);
}

/// What the object is made of.
///
/// Used for grouping in the library and for the material note on an object card.
/// It does not feed the stability maths; only weight and fragility do.
enum ObjectMaterial {
  wood,
  metal,
  plastic,
  cardboard,
  glass,
  organic,
  mixed;

  String get label => switch (this) {
    ObjectMaterial.wood => 'Wood',
    ObjectMaterial.metal => 'Metal',
    ObjectMaterial.plastic => 'Plastic',
    ObjectMaterial.cardboard => 'Cardboard',
    ObjectMaterial.glass => 'Glass',
    ObjectMaterial.organic => 'Organic',
    ObjectMaterial.mixed => 'Mixed',
  };

  static ObjectMaterial fromName(String? name) =>
      ObjectMaterial.values.firstWhere((m) => m.name == name, orElse: () => ObjectMaterial.mixed);
}

/// Library grouping, used by the filter row above the object library.
enum ObjectCategory {
  containers,
  shelving,
  kitchen,
  household,
  tools,
  samples;

  String get label => switch (this) {
    ObjectCategory.containers => 'Containers',
    ObjectCategory.shelving => 'Shelving',
    ObjectCategory.kitchen => 'Kitchen',
    ObjectCategory.household => 'Household',
    ObjectCategory.tools => 'Tools',
    ObjectCategory.samples => 'Samples',
  };

  static ObjectCategory fromName(String? name) => ObjectCategory.values.firstWhere(
    (c) => c.name == name,
    orElse: () => ObjectCategory.household,
  );
}
