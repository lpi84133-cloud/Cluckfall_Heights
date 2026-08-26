import 'dart:math' as math;

import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';

/// Every threshold the analysis uses, in one place.
///
/// They are gathered here rather than scattered through the code so they can be
/// reviewed as a set, asserted against in tests, and explained to the user. They
/// describe sensible household practice, not certified engineering limits, which
/// is why the app always calls its output an approximation.
abstract final class StabilityThresholds {
  /// Centre of mass height, as a fraction of the structure height, at which the
  /// layout becomes top-heavy.
  static const double topHeavyCaution = 0.60;
  static const double topHeavyUnstable = 0.70;

  /// Off-centre load scaled by its height. See [StabilityReport.tippingIndex].
  static const double tippingCaution = 0.22;
  static const double tippingUnstable = 0.38;

  /// Fraction of a level's assumed capacity.
  static const double overloadCaution = 1.0;
  static const double overloadUnstable = 1.3;

  /// Share of the whole structure's weight on a single level.
  static const double concentrationCaution = 0.6;

  /// Fraction of the level width the objects on it may occupy.
  static const double widthCaution = 1.0;
  static const double widthUnstable = 1.2;

  /// An object above counts as heavy for a fragile item below when it weighs at
  /// least this many times as much, and at least [heavyAbsoluteKg].
  static const double heavyRatio = 4;
  static const double heavyAbsoluteKg = 2;

  /// The concentration check needs enough levels and enough objects to be
  /// meaningful advice rather than a remark about the obvious.
  static const int minimumLevelsForConcentration = 3;
  static const int minimumObjectsForConcentration = 3;
}

/// Turns a [Structure] into a [StabilityReport].
///
/// Pure and synchronous: same input, same output, no I/O. That is what lets the
/// rearrangement planner call it hundreds of times while scoring candidate moves,
/// and what lets the rules be tested without a widget in sight.
abstract final class StabilityAnalyzer {
  static StabilityReport analyse(Structure structure) {
    if (structure.isEmpty || structure.heightCm <= 0) {
      return StabilityReport.empty;
    }

    final double totalWeight = structure.totalWeightKg;
    final List<Finding> findings = [];

    final _MassResult mass = _computeMass(structure, totalWeight);
    final List<LevelLoad> loads = _computeLoads(structure, totalWeight);

    findings
      ..addAll(_checkTopHeavy(mass))
      ..addAll(_checkTipping(mass))
      ..addAll(_checkLevels(structure, loads))
      ..addAll(_checkConcentration(structure, loads))
      ..addAll(_checkFragile(structure, loads));

    findings.sort((a, b) => a.sortKey.compareTo(b.sortKey));

    StabilityStatus status = StabilityStatus.stable;
    for (final Finding finding in findings) {
      status = status.worseOf(finding.severity);
    }

    return StabilityReport(
      status: status,
      totalWeightKg: totalWeight,
      centreOfMassX: mass.x,
      centreOfMassHeight: mass.heightFraction,
      tippingIndex: mass.tippingIndex,
      upperHalfShare: mass.upperHalfShare,
      levelLoads: loads,
      findings: List.unmodifiable(findings),
      objectCount: structure.objectCount,
    );
  }

  static _MassResult _computeMass(Structure structure, double totalWeight) {
    if (totalWeight <= 0) {
      return const _MassResult(x: 0, heightFraction: 0, upperHalfShare: 0);
    }

    double momentX = 0;
    double momentY = 0;
    double upperWeight = 0;
    final double midHeight = structure.heightCm / 2;

    for (int levelIndex = 0; levelIndex < structure.levels.length; levelIndex++) {
      final StorageLevel level = structure.levels[levelIndex];
      final double base = structure.baseHeightOf(levelIndex);

      for (final PlacedObject object in level.objects) {
        final double centreHeight = base + object.heightCm / 2;
        momentX += object.weightKg * object.slot.offset;
        momentY += object.weightKg * centreHeight;
        if (centreHeight > midHeight) {
          upperWeight += object.weightKg;
        }
      }
    }

    return _MassResult(
      x: momentX / totalWeight,
      heightFraction: (momentY / totalWeight / structure.heightCm).clamp(0.0, 1.0),
      upperHalfShare: upperWeight / totalWeight,
    );
  }

  static List<LevelLoad> _computeLoads(Structure structure, double totalWeight) {
    return [
      for (int i = 0; i < structure.levels.length; i++)
        LevelLoad(
          levelIndex: i,
          weightKg: structure.levels[i].loadKg,
          share: totalWeight <= 0 ? 0 : structure.levels[i].loadKg / totalWeight,
          capacityUse: structure.levels[i].capacityUse,
          capacityKg: structure.levels[i].capacityKg,
          objectCount: structure.levels[i].objects.length,
          fragileCount: structure.levels[i].objects
              .where((o) => o.fragility.needsProtection)
              .length,
        ),
    ];
  }

  static Iterable<Finding> _checkTopHeavy(_MassResult mass) {
    final double height = mass.heightFraction;
    if (height < StabilityThresholds.topHeavyCaution) return const [];

    final bool severe = height >= StabilityThresholds.topHeavyUnstable;
    final int percent = (height * 100).round();

    return [
      Finding(
        kind: FindingKind.topHeavy,
        severity: severe ? StabilityStatus.unstable : StabilityStatus.caution,
        message: severe
            ? 'The combined weight is centred at $percent% of the height. Move the heaviest '
                  'items down a level or two.'
            : 'The combined weight is centred at $percent% of the height, a little higher '
                  'than ideal.',
      ),
    ];
  }

  static Iterable<Finding> _checkTipping(_MassResult mass) {
    final double index = mass.tippingIndex;
    if (index < StabilityThresholds.tippingCaution) return const [];

    final bool severe = index >= StabilityThresholds.tippingUnstable;
    final String side = mass.x < 0 ? 'left' : 'right';

    return [
      Finding(
        kind: FindingKind.tippingRisk,
        severity: severe ? StabilityStatus.unstable : StabilityStatus.caution,
        message: severe
            ? 'Most of the weight sits high and towards the $side. Spread it across the '
                  'other side or move it lower.'
            : 'The load leans towards the $side. Balancing it would help.',
      ),
    ];
  }

  static Iterable<Finding> _checkLevels(Structure structure, List<LevelLoad> loads) {
    final List<Finding> findings = [];

    for (final LevelLoad load in loads) {
      if (load.capacityUse > StabilityThresholds.overloadCaution) {
        final bool severe = load.capacityUse >= StabilityThresholds.overloadUnstable;
        findings.add(
          Finding(
            kind: FindingKind.levelOverloaded,
            severity: severe ? StabilityStatus.unstable : StabilityStatus.caution,
            levelIndex: load.levelIndex,
            message:
                'Level ${load.levelNumber} carries ${_kg(load.weightKg)} against an assumed '
                '${_kg(load.capacityKg)}. Move something off it, or raise the level capacity '
                'if your shelf takes more.',
          ),
        );
      }

      final StorageLevel level = structure.levels[load.levelIndex];
      final double widthUse = structure.widthCm <= 0 ? 0 : level.usedWidthCm / structure.widthCm;
      if (widthUse > StabilityThresholds.widthCaution) {
        findings.add(
          Finding(
            kind: FindingKind.levelWidthExceeded,
            severity: widthUse >= StabilityThresholds.widthUnstable
                ? StabilityStatus.unstable
                : StabilityStatus.caution,
            levelIndex: load.levelIndex,
            message:
                'The items on level ${load.levelNumber} add up to ${_cm(level.usedWidthCm)} '
                'across, more than the ${_cm(structure.widthCm)} available.',
          ),
        );
      }

      for (final PlacedObject object in level.objects) {
        if (object.heightCm > level.clearanceCm) {
          findings.add(
            Finding(
              kind: FindingKind.levelHeightExceeded,
              severity: StabilityStatus.caution,
              levelIndex: load.levelIndex,
              objectId: object.id,
              message:
                  '${object.name} is ${_cm(object.heightCm)} tall but level '
                  '${load.levelNumber} only has ${_cm(level.clearanceCm)} of clearance.',
            ),
          );
        }
      }
    }

    return findings;
  }

  /// Weight bunched onto one level.
  ///
  /// Deliberately silent about the bottom level: putting everything low down is
  /// exactly what the app recommends elsewhere, and warning about it would
  /// contradict the rest of the analysis. It also stays quiet when there are too
  /// few objects to spread, because "distribute your single box" is not advice.
  static Iterable<Finding> _checkConcentration(Structure structure, List<LevelLoad> loads) {
    if (structure.levels.length < StabilityThresholds.minimumLevelsForConcentration) {
      return const [];
    }
    if (structure.objectCount < StabilityThresholds.minimumObjectsForConcentration) {
      return const [];
    }

    for (final LevelLoad load in loads) {
      if (load.levelIndex == 0) continue;
      if (load.share > StabilityThresholds.concentrationCaution && load.objectCount > 0) {
        return [
          Finding(
            kind: FindingKind.weightConcentrated,
            severity: StabilityStatus.caution,
            levelIndex: load.levelIndex,
            message:
                'Level ${load.levelNumber} holds ${(load.share * 100).round()}% of the total '
                'weight. Spreading it out would even the load.',
          ),
        ];
      }
    }
    return const [];
  }

  static Iterable<Finding> _checkFragile(Structure structure, List<LevelLoad> loads) {
    final List<Finding> findings = [];

    for (int index = 0; index < structure.levels.length; index++) {
      final StorageLevel level = structure.levels[index];
      final StorageLevel? above = index + 1 < structure.levels.length
          ? structure.levels[index + 1]
          : null;

      for (final PlacedObject object in level.objects) {
        if (!object.fragility.needsProtection) continue;

        if (above != null) {
          final double threshold = math.max(
            StabilityThresholds.heavyAbsoluteKg,
            object.weightKg * StabilityThresholds.heavyRatio,
          );
          final PlacedObject? heavy = _heaviestAbove(above, object, threshold);

          if (heavy != null) {
            findings.add(
              Finding(
                kind: FindingKind.fragileUnderHeavy,
                severity: object.fragility == Fragility.fragile
                    ? StabilityStatus.unstable
                    : StabilityStatus.caution,
                levelIndex: index,
                objectId: object.id,
                relatedObjectId: heavy.id,
                message:
                    '${object.name} on level ${index + 1} sits under ${heavy.name} '
                    '(${_kg(heavy.weightKg)}) on level ${index + 2}. Swap them, or move the '
                    '${object.name.toLowerCase()} to its own level.',
              ),
            );
          }
        }

        if (loads[index].isOverloaded) {
          findings.add(
            Finding(
              kind: FindingKind.fragileOnOverloadedLevel,
              severity: StabilityStatus.caution,
              levelIndex: index,
              objectId: object.id,
              message:
                  '${object.name} is on level ${index + 1}, which is over its assumed '
                  'capacity. Fragile items are safer on a level with room to spare.',
            ),
          );
        }
      }
    }

    return findings;
  }

  /// The heaviest object above that is also roughly over the fragile item.
  ///
  /// Objects in different thirds of the level are not above each other, so a jar
  /// on the left and a tool box on the right is not a problem, and the analysis
  /// should not claim it is.
  static PlacedObject? _heaviestAbove(
    StorageLevel above,
    PlacedObject fragile,
    double threshold,
  ) {
    PlacedObject? found;
    for (final PlacedObject candidate in above.objects) {
      if (candidate.slot != fragile.slot) continue;
      if (candidate.weightKg < threshold) continue;
      if (found == null || candidate.weightKg > found.weightKg) found = candidate;
    }
    return found;
  }

  static String _kg(double value) =>
      '${value.toStringAsFixed(value < 10 ? 1 : 0).replaceAll(RegExp(r'\.0$'), '')} kg';

  static String _cm(double value) => '${value.round()} cm';
}

class _MassResult {
  const _MassResult({
    required this.x,
    required this.heightFraction,
    required this.upperHalfShare,
  });

  final double x;
  final double heightFraction;
  final double upperHalfShare;

  double get tippingIndex => x.abs() * heightFraction;
}
