import 'package:cluckfall_heights/domain/insights/portfolio_insights.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/structure_builder.dart';

void main() {
  group('an empty library', () {
    test('produces the empty value rather than zeroed guesses', () {
      final PortfolioInsights insights = PortfolioInsights.from(const []);

      expect(insights.isEmpty, isTrue);
      expect(insights.hasPlacements, isFalse);
      expect(insights.planCount, 0);
      expect(insights.materials, isEmpty);
      expect(insights.topObjects, isEmpty);
      expect(insights.plans, isEmpty);
    });

    test('derived figures do not divide by zero', () {
      final PortfolioInsights insights = PortfolioInsights.from(const []);

      expect(insights.capacityUse, 0);
      expect(insights.headroomKg, 0);
      expect(insights.averageObjectsPerPlan, 0);
      expect(insights.averageCentreOfMass, 0);
      expect(insights.balanceVerdict, 'Nothing placed yet');
    });
  });

  group('a plan with no objects', () {
    test('counts as a plan but not as placements', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([[], [], []]),
      ]);

      expect(insights.planCount, 1);
      expect(insights.objectCount, 0);
      expect(insights.hasPlacements, isFalse);
      expect(insights.levelCount, 3);
      expect(insights.emptyLevelCount, 3);
      expect(insights.filledLevelCount, 0);
    });

    test('its capacity is available headroom', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([[], []], capacityKg: 20),
      ]);

      expect(insights.totalCapacityKg, 40);
      expect(insights.headroomKg, 40);
      expect(insights.capacityUse, 0);
    });
  });

  group('totals', () {
    test('weight and counts add up across plans', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('a', weightKg: 5)],
          [item('b', weightKg: 3)],
        ], id: 'one'),
        structureOf([
          [item('c', weightKg: 2)],
        ], id: 'two'),
      ]);

      expect(insights.planCount, 2);
      expect(insights.objectCount, 3);
      expect(insights.totalWeightKg, closeTo(10, 0.001));
      expect(insights.averageObjectsPerPlan, closeTo(1.5, 0.001));
    });

    test('empty and filled levels are told apart', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('a', weightKg: 1)],
          [],
          [item('b', weightKg: 1)],
          [],
        ]),
      ]);

      expect(insights.levelCount, 4);
      expect(insights.emptyLevelCount, 2);
      expect(insights.filledLevelCount, 2);
    });

    test('fragile and delicate items are counted separately', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [
            item('glass', weightKg: 1, fragility: Fragility.fragile),
            item('box', weightKg: 1, fragility: Fragility.delicate),
            item('tin', weightKg: 1),
          ],
        ]),
      ]);

      expect(insights.fragileCount, 1);
      expect(insights.delicateCount, 1);
      expect(insights.protectedCount, 2);
    });

    test('the heaviest single object is named', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('light', weightKg: 1)],
        ], id: 'one'),
        structureOf([
          [item('anvil', weightKg: 40, name: 'Anvil')],
        ], id: 'two'),
      ]);

      expect(insights.heaviestObjectKg, 40);
      expect(insights.heaviestObjectName, 'Anvil');
    });
  });

  group('capacity', () {
    test('headroom is what is left below the assumed limits', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('a', weightKg: 10)],
          [],
        ], capacityKg: 25),
      ]);

      expect(insights.totalCapacityKg, 50);
      expect(insights.capacityUse, closeTo(0.2, 0.001));
      expect(insights.headroomKg, closeTo(40, 0.001));
    });

    test('an overloaded portfolio reports no headroom rather than a negative', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('a', weightKg: 60)],
        ], capacityKg: 10),
      ]);

      expect(insights.capacityUse, greaterThan(1));
      expect(insights.headroomKg, 0);
    });
  });

  group('status roll-up', () {
    test('every plan lands in exactly one status bucket', () {
      final List<Structure> structures = [
        structureOf([
          [item('a', weightKg: 2)],
          [],
        ], id: 'one'),
        structureOf([
          [],
          [],
          [item('heavy', weightKg: 40)],
        ], id: 'two', capacityKg: 60),
      ];

      final PortfolioInsights insights = PortfolioInsights.from(structures);
      final int bucketed =
          insights.stablePlans + insights.cautionPlans + insights.unstablePlans;

      expect(bucketed, structures.length);
    });

    test('plans needing work is the sum of caution and unsound', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [],
          [],
          [item('heavy', weightKg: 40)],
        ], capacityKg: 60),
      ]);

      expect(
        insights.plansNeedingWork,
        insights.cautionPlans + insights.unstablePlans,
      );
    });
  });

  group('material breakdown', () {
    test('weight is grouped by material and sorted heaviest first', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [
            item('board', weightKg: 2, material: ObjectMaterial.wood),
            item('tin', weightKg: 8, material: ObjectMaterial.metal),
            item('plank', weightKg: 3, material: ObjectMaterial.wood),
          ],
        ]),
      ]);

      expect(insights.materials.length, 2);
      expect(insights.materials.first.material, ObjectMaterial.metal);
      expect(insights.materials.first.weightKg, closeTo(8, 0.001));
      expect(insights.materials.last.material, ObjectMaterial.wood);
      expect(insights.materials.last.weightKg, closeTo(5, 0.001));
      expect(insights.materials.last.objectCount, 2);
    });

    test('shares are fractions of the total weight and sum to one', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [
            item('a', weightKg: 3, material: ObjectMaterial.glass),
            item('b', weightKg: 1, material: ObjectMaterial.metal),
          ],
        ]),
      ]);

      expect(insights.materials.first.share, closeTo(0.75, 0.001));
      final double total = insights.materials.fold<double>(
        0,
        (sum, share) => sum + share.share,
      );
      expect(total, closeTo(1, 0.001));
    });
  });

  group('most-placed objects', () {
    test('placements of the same profile are counted together', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [
            item('j1', weightKg: 1, name: 'Jar'),
            item('j2', weightKg: 1, name: 'Jar'),
            item('b1', weightKg: 1, name: 'Bottle'),
          ],
        ]),
      ]);

      final ObjectUsage jar = insights.topObjects.firstWhere((u) => u.name == 'Jar');
      expect(jar.placements, 2);
      expect(jar.weightKg, closeTo(2, 0.001));
    });

    test('the list is ordered by placements and capped by the limit', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [
            item('a1', weightKg: 1, name: 'Alpha'),
            item('b1', weightKg: 1, name: 'Beta'),
            item('b2', weightKg: 1, name: 'Beta'),
            item('c1', weightKg: 1, name: 'Gamma'),
            item('c2', weightKg: 1, name: 'Gamma'),
            item('c3', weightKg: 1, name: 'Gamma'),
          ],
        ]),
      ], topObjectLimit: 2);

      expect(insights.topObjects.length, 2);
      expect(insights.topObjects[0].name, 'Gamma');
      expect(insights.topObjects[1].name, 'Beta');
    });

    test('placements spanning plans are still one entry', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('x', weightKg: 1, name: 'Jar')],
        ], id: 'one'),
        structureOf([
          [item('y', weightKg: 1, name: 'Jar')],
        ], id: 'two'),
      ]);

      expect(insights.topObjects.length, 1);
      expect(insights.topObjects.single.placements, 2);
    });
  });

  group('plan digests', () {
    test('are sorted heaviest first and carry their own status', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('light', weightKg: 2)],
        ], id: 'light-plan', name: 'Light'),
        structureOf([
          [item('heavy', weightKg: 20)],
        ], id: 'heavy-plan', name: 'Heavy'),
      ]);

      expect(insights.plans.first.name, 'Heavy');
      expect(insights.plans.first.id, 'heavy-plan');
      expect(insights.plans.first.weightKg, closeTo(20, 0.001));
      expect(insights.plans.last.name, 'Light');
      expect(insights.plans.last.weightKg, closeTo(2, 0.001));
    });

    test('the findings total matches the sum over plans', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [],
          [],
          [item('heavy', weightKg: 40)],
        ], id: 'one', capacityKg: 60),
        structureOf([
          [item('fine', weightKg: 2)],
        ], id: 'two'),
      ]);

      final int summed = insights.plans.fold<int>(
        0,
        (sum, plan) => sum + plan.findingCount,
      );
      expect(insights.findingCount, summed);
    });
  });

  group('balance', () {
    test('weight low down reads as a low centre of mass', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('heavy', weightKg: 30)],
          [],
          [],
        ]),
      ]);

      expect(insights.averageCentreOfMass, lessThan(0.4));
      expect(insights.balanceVerdict, 'Loaded low, which is ideal');
    });

    test('weight up high reads as top-heavy', () {
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [],
          [],
          [item('heavy', weightKg: 30)],
        ]),
      ]);

      expect(insights.averageCentreOfMass, greaterThan(0.6));
    });

    test('the average is weighted by plan weight, not by plan count', () {
      // One heavy plan loaded low, one nearly empty plan loaded high. Weighting
      // by mass must keep the overall figure near the heavy plan's.
      final PortfolioInsights insights = PortfolioInsights.from([
        structureOf([
          [item('heavy', weightKg: 100)],
          [],
          [],
        ], id: 'heavy-low'),
        structureOf([
          [],
          [],
          [item('feather', weightKg: 0.1)],
        ], id: 'light-high'),
      ]);

      expect(insights.averageCentreOfMass, lessThan(0.4));
    });
  });
}
