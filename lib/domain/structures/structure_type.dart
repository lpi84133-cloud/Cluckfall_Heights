import 'package:cluckfall_heights/core/assets/app_assets.dart';

/// The four kinds of storage the app can plan.
enum StructureType {
  shelf,
  cabinet,
  storageBox,
  custom;

  String get label => switch (this) {
    StructureType.shelf => 'Shelf',
    StructureType.cabinet => 'Cabinet',
    StructureType.storageBox => 'Storage Box',
    StructureType.custom => 'Custom Structure',
  };

  String get description => switch (this) {
    StructureType.shelf => 'Open shelving and racks.',
    StructureType.cabinet => 'Enclosed units with internal levels.',
    StructureType.storageBox => 'A single box or container, stacked inside.',
    StructureType.custom => 'Set every dimension yourself.',
  };

  /// Starting dimensions in centimetres, so the user is never handed an empty
  /// form. They stay editable on every screen that shows them.
  ({double width, double depth, double height, int levels}) get defaults => switch (this) {
    StructureType.shelf => (width: 90, depth: 30, height: 180, levels: 4),
    StructureType.cabinet => (width: 60, depth: 40, height: 200, levels: 5),
    StructureType.storageBox => (width: 50, depth: 35, height: 40, levels: 2),
    StructureType.custom => (width: 80, depth: 35, height: 160, levels: 3),
  };

  /// Load a single level is assumed to take, per centimetre of width.
  ///
  /// Open shelving and cabinets are boarded and carry more than a plastic box
  /// lid, and this is what the overload check measures against. It is an
  /// assumption offered as a default, and every level exposes its own editable
  /// capacity so the user can correct it for their actual furniture.
  double get loadPerCmWidth => switch (this) {
    StructureType.shelf => 0.28,
    StructureType.cabinet => 0.33,
    StructureType.storageBox => 0.18,
    StructureType.custom => 0.25,
  };

  /// Backdrop used when this structure is shown in the builder.
  String get backgroundAsset => switch (this) {
    StructureType.shelf => BackgroundArt.storageRoom,
    StructureType.cabinet => BackgroundArt.kitchenCabinet,
    StructureType.storageBox => BackgroundArt.garage,
    StructureType.custom => BackgroundArt.pantry,
  };

  static StructureType fromName(String? name) =>
      StructureType.values.firstWhere((t) => t.name == name, orElse: () => StructureType.shelf);
}
