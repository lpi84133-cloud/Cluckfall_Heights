import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/structure_builder.dart';

Iterable<FindingKind> kindsOf(StabilityReport report) => report.findings.map((f) => f.kind);

void main() {
  group('empty and trivial layouts', () {
    test('a structure with nothing in it reports empty rather than stable', () {
      final StabilityReport report = StabilityAnalyzer.analyse(structureOf([[], [], []]));

      expect(report.isEmpty, isTrue);
      expect(report.findings, isEmpty);
      expect(report.totalWeightKg, 0);
    });

    test('weight on the bottom level is stable', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 8)],
          [],
          [],
          [],
        ]),
      );

      expect(report.status, StabilityStatus.stable);
      expect(report.findings, isEmpty);
      expect(report.centreOfMassHeight, lessThan(0.2));
    });
  });

  group('centre of mass', () {
    test('is weighted by mass, not by object count', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('heavy', weightKg: 20)],
          [item('light.a', weightKg: 0.5), item('light.b', weightKg: 0.5)],
          [],
          [],
        ]),
      );

      // The heavy item on the bottom level dominates, so the centre of mass must
      // stay near the floor even though the level above holds two objects.
      expect(report.centreOfMassHeight, lessThan(0.25));
      expect(report.status, StabilityStatus.stable);
    });

    test('sits high when the load is on the top level, and is flagged', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [],
          [],
          [],
          [item('box', weightKg: 10)],
        ]),
      );

      expect(report.centreOfMassHeight, greaterThan(StabilityThresholds.topHeavyUnstable));
      expect(kindsOf(report), contains(FindingKind.topHeavy));
      expect(report.status, StabilityStatus.unstable);
    });

    test('horizontal offset follows the slot the object stands in', () {
      final StabilityReport left = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 10, slot: LevelSlot.left)],
        ]),
      );
      final StabilityReport centred = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 10)],
        ]),
      );

      expect(left.centreOfMassX, lessThan(0));
      expect(centred.centreOfMassX, 0);
    });

    test('opposite slots on the same level cancel out', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [
            item('a', weightKg: 5, slot: LevelSlot.left),
            item('b', weightKg: 5, slot: LevelSlot.right),
          ],
        ]),
      );

      expect(report.centreOfMassX, closeTo(0, 1e-9));
      expect(kindsOf(report), isNot(contains(FindingKind.tippingRisk)));
    });
  });

  group('tipping', () {
    test('an off-centre load near the floor is not flagged', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 10, slot: LevelSlot.left)],
          [],
          [],
          [],
        ]),
      );

      expect(report.tippingIndex, lessThan(StabilityThresholds.tippingCaution));
      expect(kindsOf(report), isNot(contains(FindingKind.tippingRisk)));
    });

    test('the same load high up is flagged', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [],
          [],
          [],
          [item('box', weightKg: 10, slot: LevelSlot.left)],
        ]),
      );

      expect(kindsOf(report), contains(FindingKind.tippingRisk));
      expect(report.findings.firstWhere((f) => f.kind == FindingKind.tippingRisk).message,
          contains('left'));
    });
  });

  group('level capacity', () {
    test('over capacity is caution, well over is unstable', () {
      final StabilityReport over = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 27)],
          [],
          [],
        ], capacityKg: 25),
      );
      final StabilityReport wayOver = StabilityAnalyzer.analyse(
        structureOf([
          [item('box', weightKg: 40)],
          [],
          [],
        ], capacityKg: 25),
      );

      expect(
        over.findings.firstWhere((f) => f.kind == FindingKind.levelOverloaded).severity,
        StabilityStatus.caution,
      );
      expect(
        wayOver.findings.firstWhere((f) => f.kind == FindingKind.levelOverloaded).severity,
        StabilityStatus.unstable,
      );
    });

    test('the message names the level and both weights', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [],
          [item('box', weightKg: 30)],
          [],
        ], capacityKg: 25),
      );

      final Finding finding = report.findings.firstWhere(
        (f) => f.kind == FindingKind.levelOverloaded,
      );
      expect(finding.levelNumber, 2);
      expect(finding.message, contains('Level 2'));
      expect(finding.message, contains('30 kg'));
      expect(finding.message, contains('25 kg'));
    });
  });

  group('fragile items', () {
    test('a fragile item under a heavy one in the same slot is unstable', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
          [item('toolbox', weightKg: 9.8)],
        ]),
      );

      final Finding finding = report.findings.firstWhere(
        (f) => f.kind == FindingKind.fragileUnderHeavy,
      );
      expect(finding.severity, StabilityStatus.unstable);
      expect(finding.objectId, 'jar');
      expect(finding.relatedObjectId, 'toolbox');
    });

    test('a delicate item under a heavy one is only a caution', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('carton', weightKg: 1, fragility: Fragility.delicate)],
          [item('toolbox', weightKg: 9.8)],
        ]),
      );

      expect(
        report.findings.firstWhere((f) => f.kind == FindingKind.fragileUnderHeavy).severity,
        StabilityStatus.caution,
      );
    });

    test('items in different slots are not treated as stacked', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('jar', weightKg: 0.9, fragility: Fragility.fragile, slot: LevelSlot.left)],
          [item('toolbox', weightKg: 9.8, slot: LevelSlot.right)],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.fragileUnderHeavy)));
    });

    test('a light item above a fragile one is not a problem', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
          [item('book', weightKg: 0.7)],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.fragileUnderHeavy)));
    });

    test('only the level directly above counts', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
          [],
          [item('toolbox', weightKg: 9.8)],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.fragileUnderHeavy)));
    });

    test('a fragile item on an overloaded level is called out separately', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [
            item('jar', weightKg: 0.9, fragility: Fragility.fragile),
            item('anvil', weightKg: 30),
          ],
          [],
          [],
        ], capacityKg: 25),
      );

      expect(kindsOf(report), contains(FindingKind.fragileOnOverloadedLevel));
    });
  });

  group('geometry that does not fit', () {
    test('objects wider than the structure are reported', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [
            item('a', weightKg: 1, widthCm: 50),
            item('b', weightKg: 1, widthCm: 50),
          ],
        ], widthCm: 90),
      );

      final Finding finding = report.findings.firstWhere(
        (f) => f.kind == FindingKind.levelWidthExceeded,
      );
      expect(finding.message, contains('100 cm'));
      expect(finding.message, contains('90 cm'));
    });

    test('an object taller than its clearance is reported', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('bottle', weightKg: 1, heightCm: 70)],
          [],
          [],
        ], heightCm: 180),
      );

      expect(kindsOf(report), contains(FindingKind.levelHeightExceeded));
    });
  });

  group('weight concentration', () {
    test('one level above the bottom holding most of the weight is a caution', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('light', weightKg: 1)],
          [item('heavy', weightKg: 20)],
          [item('light.b', weightKg: 1)],
        ]),
      );

      expect(kindsOf(report), contains(FindingKind.weightConcentrated));
    });

    test('everything on the bottom level is not a concentration problem', () {
      // Loading the bottom level is what the rest of the analysis recommends, so
      // warning about it here would contradict the advice given elsewhere.
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('heavy', weightKg: 20), item('a', weightKg: 1), item('b', weightKg: 1)],
          [],
          [],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.weightConcentrated)));
    });

    test('a two level structure is not judged on concentration', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('light', weightKg: 1)],
          [item('heavy', weightKg: 20)],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.weightConcentrated)));
    });

    test('a single object is never called a concentration', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [],
          [item('heavy', weightKg: 8)],
          [],
        ]),
      );

      expect(kindsOf(report), isNot(contains(FindingKind.weightConcentrated)));
    });
  });

  group('findings order', () {
    test('the most important problem comes first', () {
      final StabilityReport report = StabilityAnalyzer.analyse(
        structureOf([
          [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
          [item('toolbox', weightKg: 30)],
        ], capacityKg: 25),
      );

      // Both a fragile risk and an overloaded level are present. The fragile
      // risk ranks higher, so it is the one the builder screen would show.
      expect(report.findings.length, greaterThan(1));
      expect(report.primaryFinding!.kind, FindingKind.fragileUnderHeavy);
      expect(kindsOf(report), contains(FindingKind.levelOverloaded));
      for (int i = 1; i < report.findings.length; i++) {
        expect(
          report.findings[i - 1].sortKey,
          lessThanOrEqualTo(report.findings[i].sortKey),
        );
      }
    });
  });

  group('level loads', () {
    test('shares add up to the whole and capacity use is reported per level', () {
      final Structure structure = structureOf([
        [item('a', weightKg: 6)],
        [item('b', weightKg: 2)],
        [],
      ], capacityKg: 20);
      final StabilityReport report = StabilityAnalyzer.analyse(structure);

      expect(report.totalWeightKg, 8);
      expect(report.levelLoads.map((l) => l.share).reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(report.levelLoads[0].capacityUse, closeTo(0.3, 1e-9));
      expect(report.levelIndexWithMostWeight, 0);
    });
  });
}
