/// Where along a level an object sits.
///
/// Each level is divided into three zones instead of using free coordinates.
/// Three drop targets are easy to hit with a thumb, easy to read at a glance,
/// and enough to make the horizontal centre of mass mean something: without an
/// explicit side, every layout would compute as perfectly centred and the
/// balance analysis would have nothing to say.
enum LevelSlot {
  left,
  centre,
  right;

  String get label => switch (this) {
    LevelSlot.left => 'Left',
    LevelSlot.centre => 'Centre',
    LevelSlot.right => 'Right',
  };

  /// Horizontal position of the zone centre, in units of half the level width,
  /// so -1 is the left edge and 1 is the right edge.
  double get offset => switch (this) {
    LevelSlot.left => -2 / 3,
    LevelSlot.centre => 0,
    LevelSlot.right => 2 / 3,
  };

  static LevelSlot fromName(String? name) =>
      LevelSlot.values.firstWhere((s) => s.name == name, orElse: () => LevelSlot.centre);
}
