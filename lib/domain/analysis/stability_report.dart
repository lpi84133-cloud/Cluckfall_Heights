import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:meta/meta.dart';

/// Load on a single level, for the weight distribution view.
@immutable
class LevelLoad {
  const LevelLoad({
    required this.levelIndex,
    required this.weightKg,
    required this.share,
    required this.capacityUse,
    required this.capacityKg,
    required this.objectCount,
    required this.fragileCount,
  });

  final int levelIndex;
  final double weightKg;

  /// Fraction of the structure's total weight, 0 to 1.
  final double share;

  /// Fraction of this level's assumed capacity in use. Above 1 is overloaded.
  final double capacityUse;

  final double capacityKg;
  final int objectCount;
  final int fragileCount;

  int get levelNumber => levelIndex + 1;

  bool get isOverloaded => capacityUse > 1;
}

/// Everything the analysis produced for one structure.
///
/// This is a plain value object with no behaviour beyond reading: the screens
/// render it, the rearrangement planner scores it, and the tests assert on it.
@immutable
class StabilityReport {
  const StabilityReport({
    required this.status,
    required this.totalWeightKg,
    required this.centreOfMassX,
    required this.centreOfMassHeight,
    required this.tippingIndex,
    required this.upperHalfShare,
    required this.levelLoads,
    required this.findings,
    required this.objectCount,
  });

  static const StabilityReport empty = StabilityReport(
    status: StabilityStatus.stable,
    totalWeightKg: 0,
    centreOfMassX: 0,
    centreOfMassHeight: 0,
    tippingIndex: 0,
    upperHalfShare: 0,
    levelLoads: [],
    findings: [],
    objectCount: 0,
  );

  final StabilityStatus status;
  final double totalWeightKg;

  /// Horizontal centre of mass in units of half the structure width: -1 is the
  /// left edge, 0 the middle, 1 the right edge.
  final double centreOfMassX;

  /// Height of the centre of mass as a fraction of the structure height.
  final double centreOfMassHeight;

  /// How far off centre the load is, scaled by how high it sits. An offset load
  /// near the floor barely matters; the same offset near the top does.
  final double tippingIndex;

  /// Share of the total weight above the halfway height, 0 to 1.
  final double upperHalfShare;

  final List<LevelLoad> levelLoads;

  /// Sorted by importance, most important first.
  final List<Finding> findings;

  final int objectCount;

  bool get isEmpty => objectCount == 0;

  /// The one problem worth showing on the builder screen.
  Finding? get primaryFinding => findings.isEmpty ? null : findings.first;

  int get levelIndexWithMostWeight {
    if (levelLoads.isEmpty) return -1;
    LevelLoad heaviest = levelLoads.first;
    for (final LevelLoad load in levelLoads) {
      if (load.weightKg > heaviest.weightKg) heaviest = load;
    }
    return heaviest.weightKg <= 0 ? -1 : heaviest.levelIndex;
  }

  Iterable<Finding> findingsForLevel(int levelIndex) =>
      findings.where((f) => f.levelIndex == levelIndex);

  Iterable<Finding> findingsForObject(String objectId) =>
      findings.where((f) => f.objectId == objectId || f.relatedObjectId == objectId);
}
