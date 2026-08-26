import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:meta/meta.dart';

/// How much weight one material accounts for across every saved plan.
@immutable
class MaterialShare {
  const MaterialShare({
    required this.material,
    required this.weightKg,
    required this.objectCount,
    required this.share,
  });

  final ObjectMaterial material;
  final double weightKg;
  final int objectCount;

  /// Fraction of the total planned weight, 0-1.
  final double share;
}

/// One library profile and how often it has actually been placed.
@immutable
class ObjectUsage {
  const ObjectUsage({
    required this.name,
    required this.placements,
    required this.weightKg,
    required this.artAsset,
  });

  final String name;

  /// How many times this profile appears across all plans.
  final int placements;

  /// Combined weight of every placement.
  final double weightKg;

  final String? artAsset;
}

/// A plan reduced to the few numbers worth ranking it by.
@immutable
class PlanDigest {
  const PlanDigest({
    required this.id,
    required this.name,
    required this.weightKg,
    required this.objectCount,
    required this.status,
    required this.findingCount,
  });

  final String id;
  final String name;
  final double weightKg;
  final int objectCount;
  final StabilityStatus status;
  final int findingCount;
}

/// Everything the user has planned, read as one picture.
///
/// The builder answers "is this shelf sound". This answers the questions that
/// only make sense across plans: how much is stored in total, what it is made
/// of, how much room is left, and which plans still need attention.
///
/// Every figure is derived from saved data. Nothing here is invented, and an
/// empty library produces [PortfolioInsights.empty] rather than placeholder
/// numbers.
@immutable
class PortfolioInsights {
  const PortfolioInsights({
    required this.planCount,
    required this.objectCount,
    required this.levelCount,
    required this.emptyLevelCount,
    required this.totalWeightKg,
    required this.totalCapacityKg,
    required this.stablePlans,
    required this.cautionPlans,
    required this.unstablePlans,
    required this.findingCount,
    required this.fragileCount,
    required this.delicateCount,
    required this.averageCentreOfMass,
    required this.heaviestObjectKg,
    required this.heaviestObjectName,
    required this.materials,
    required this.topObjects,
    required this.plans,
  });

  static const PortfolioInsights empty = PortfolioInsights(
    planCount: 0,
    objectCount: 0,
    levelCount: 0,
    emptyLevelCount: 0,
    totalWeightKg: 0,
    totalCapacityKg: 0,
    stablePlans: 0,
    cautionPlans: 0,
    unstablePlans: 0,
    findingCount: 0,
    fragileCount: 0,
    delicateCount: 0,
    averageCentreOfMass: 0,
    heaviestObjectKg: 0,
    heaviestObjectName: null,
    materials: <MaterialShare>[],
    topObjects: <ObjectUsage>[],
    plans: <PlanDigest>[],
  );

  final int planCount;
  final int objectCount;
  final int levelCount;
  final int emptyLevelCount;

  final double totalWeightKg;

  /// Combined assumed capacity of every level in every plan.
  final double totalCapacityKg;

  final int stablePlans;
  final int cautionPlans;
  final int unstablePlans;

  /// Total open findings across every plan.
  final int findingCount;

  final int fragileCount;
  final int delicateCount;

  /// Centre of mass height averaged across plans, weighted by plan weight.
  /// Low is good: it means the heavy things are near the floor.
  final double averageCentreOfMass;

  final double heaviestObjectKg;
  final String? heaviestObjectName;

  /// Heaviest material first.
  final List<MaterialShare> materials;

  /// Most-placed profiles first, capped by the caller.
  final List<ObjectUsage> topObjects;

  /// Heaviest plan first.
  final List<PlanDigest> plans;

  bool get isEmpty => planCount == 0;

  /// True once there is enough placed for the breakdowns to say anything.
  bool get hasPlacements => objectCount > 0;

  /// Fraction of the combined capacity in use, 0-1 and beyond if overloaded.
  double get capacityUse => totalCapacityKg <= 0 ? 0 : totalWeightKg / totalCapacityKg;

  /// Weight the shelves could still take before hitting their assumed limits.
  double get headroomKg =>
      totalCapacityKg <= 0 ? 0 : (totalCapacityKg - totalWeightKg).clamp(0, totalCapacityKg);

  int get plansNeedingWork => cautionPlans + unstablePlans;

  int get filledLevelCount => levelCount - emptyLevelCount;

  double get averageObjectsPerPlan => planCount == 0 ? 0 : objectCount / planCount;

  int get protectedCount => fragileCount + delicateCount;

  /// Reads [averageCentreOfMass] as a short verdict.
  String get balanceVerdict {
    if (!hasPlacements) return 'Nothing placed yet';
    if (averageCentreOfMass <= 0.40) return 'Loaded low, which is ideal';
    if (averageCentreOfMass <= StabilityThresholds.topHeavyCaution) {
      return 'Reasonably balanced';
    }
    if (averageCentreOfMass <= StabilityThresholds.topHeavyUnstable) {
      return 'Leaning top-heavy';
    }
    return 'Too much weight up high';
  }

  /// Builds the picture from saved plans.
  ///
  /// [topObjectLimit] caps the usage list so the screen does not have to.
  factory PortfolioInsights.from(
    List<Structure> structures, {
    int topObjectLimit = 5,
  }) {
    if (structures.isEmpty) return PortfolioInsights.empty;

    int objectCount = 0;
    int levelCount = 0;
    int emptyLevelCount = 0;
    double totalWeight = 0;
    double totalCapacity = 0;
    int stable = 0;
    int caution = 0;
    int unstable = 0;
    int findings = 0;
    int fragile = 0;
    int delicate = 0;
    double comWeightedSum = 0;
    double heaviestKg = 0;
    String? heaviestName;

    final Map<ObjectMaterial, ({double kg, int count})> byMaterial = {};
    final Map<String, ({int placements, double kg, String? art})> byProfile = {};
    final List<PlanDigest> digests = [];

    for (final Structure structure in structures) {
      final StabilityReport report = StabilityAnalyzer.analyse(structure);

      levelCount += structure.levels.length;
      objectCount += structure.objectCount;
      totalWeight += report.totalWeightKg;
      findings += report.findings.length;

      for (final StorageLevel level in structure.levels) {
        totalCapacity += level.capacityKg;
        if (level.isEmpty) emptyLevelCount++;
      }

      switch (report.status) {
        case StabilityStatus.stable:
          stable++;
        case StabilityStatus.caution:
          caution++;
        case StabilityStatus.unstable:
          unstable++;
      }

      // Weighting the average by plan weight keeps a nearly empty plan from
      // dragging the figure around as much as a fully loaded one.
      comWeightedSum += report.centreOfMassHeight * report.totalWeightKg;

      for (final PlacedObject object in structure.allObjects) {
        switch (object.fragility) {
          case Fragility.fragile:
            fragile++;
          case Fragility.delicate:
            delicate++;
          case Fragility.sturdy:
            break;
        }

        if (object.weightKg > heaviestKg) {
          heaviestKg = object.weightKg;
          heaviestName = object.name;
        }

        final ({double kg, int count}) material =
            byMaterial[object.material] ?? (kg: 0, count: 0);
        byMaterial[object.material] = (
          kg: material.kg + object.weightKg,
          count: material.count + 1,
        );

        final ({int placements, double kg, String? art}) profile =
            byProfile[object.name] ?? (placements: 0, kg: 0, art: object.artAsset);
        byProfile[object.name] = (
          placements: profile.placements + 1,
          kg: profile.kg + object.weightKg,
          art: profile.art ?? object.artAsset,
        );
      }

      digests.add(
        PlanDigest(
          id: structure.id,
          name: structure.name,
          weightKg: report.totalWeightKg,
          objectCount: structure.objectCount,
          status: report.status,
          findingCount: report.findings.length,
        ),
      );
    }

    final List<MaterialShare> materials = byMaterial.entries
        .map(
          (entry) => MaterialShare(
            material: entry.key,
            weightKg: entry.value.kg,
            objectCount: entry.value.count,
            share: totalWeight <= 0 ? 0 : entry.value.kg / totalWeight,
          ),
        )
        .toList()
      ..sort((a, b) => b.weightKg.compareTo(a.weightKg));

    final List<ObjectUsage> usage = byProfile.entries
        .map(
          (entry) => ObjectUsage(
            name: entry.key,
            placements: entry.value.placements,
            weightKg: entry.value.kg,
            artAsset: entry.value.art,
          ),
        )
        .toList()
      // Ties broken by weight so the list is stable between rebuilds.
      ..sort((a, b) {
        final int byPlacements = b.placements.compareTo(a.placements);
        return byPlacements != 0 ? byPlacements : b.weightKg.compareTo(a.weightKg);
      });

    digests.sort((a, b) => b.weightKg.compareTo(a.weightKg));

    return PortfolioInsights(
      planCount: structures.length,
      objectCount: objectCount,
      levelCount: levelCount,
      emptyLevelCount: emptyLevelCount,
      totalWeightKg: totalWeight,
      totalCapacityKg: totalCapacity,
      stablePlans: stable,
      cautionPlans: caution,
      unstablePlans: unstable,
      findingCount: findings,
      fragileCount: fragile,
      delicateCount: delicate,
      averageCentreOfMass: totalWeight <= 0 ? 0 : comWeightedSum / totalWeight,
      heaviestObjectKg: heaviestKg,
      heaviestObjectName: heaviestName,
      materials: materials,
      topObjects: usage.take(topObjectLimit).toList(growable: false),
      plans: digests,
    );
  }
}
