import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement_planner.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/structure_builder.dart';

void main() {
  test('a stable layout gets no suggestions at all', () {
    final Structure structure = structureOf([
      [item('toolbox', weightKg: 9.8)],
      [item('box', weightKg: 2)],
      [item('book', weightKg: 0.7)],
      [],
    ]);

    expect(StabilityAnalyzer.analyse(structure).status, StabilityStatus.stable);
    expect(RearrangementPlanner.shouldSuggest(StabilityAnalyzer.analyse(structure)), isFalse);
    expect(RearrangementPlanner.plan(structure), isEmpty);
  });

  test('an empty structure gets no suggestions', () {
    expect(RearrangementPlanner.plan(structureOf([[], [], []])), isEmpty);
  });

  test('a top-heavy layout is offered a move that lowers the centre of mass', () {
    final Structure structure = structureOf([
      [],
      [],
      [],
      [item('toolbox', weightKg: 9.8)],
    ]);

    final List<Rearrangement> plan = RearrangementPlanner.plan(structure);
    expect(plan, isNotEmpty);

    final Rearrangement best = plan.first;
    expect(best.objectId, 'toolbox');
    expect(best.kind, RearrangementKind.move);
    expect(best.targetLevelIndex, lessThan(3));

    final Structure applied = RearrangementPlanner.apply(structure, best);
    final StabilityReport after = StabilityAnalyzer.analyse(applied);
    expect(after.centreOfMassHeight, lessThan(StabilityAnalyzer.analyse(structure).centreOfMassHeight));
  });

  test('every suggestion actually improves the layout it is offered for', () {
    final Structure structure = structureOf([
      [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
      [item('toolbox', weightKg: 9.8)],
      [item('crate', weightKg: 7)],
      [item('box', weightKg: 4)],
    ]);

    final StabilityReport before = StabilityAnalyzer.analyse(structure);
    final double baseScore = RearrangementPlanner.score(before);
    final List<Rearrangement> plan = RearrangementPlanner.plan(structure);

    expect(plan, isNotEmpty);
    for (final Rearrangement suggestion in plan) {
      final StabilityReport after = StabilityAnalyzer.analyse(
        RearrangementPlanner.apply(structure, suggestion),
      );
      expect(
        RearrangementPlanner.score(after),
        lessThan(baseScore),
        reason: '${suggestion.title} did not improve the score',
      );
      expect(after.status.index, lessThanOrEqualTo(before.status.index));
    }
  });

  test('suggestions are ranked best first and never repeat an object', () {
    final Structure structure = structureOf([
      [],
      [item('toolbox', weightKg: 9.8), item('crate', weightKg: 7)],
      [item('box', weightKg: 5)],
      [item('bag', weightKg: 3)],
    ]);

    final List<Rearrangement> plan = RearrangementPlanner.plan(structure);
    expect(plan.length, greaterThan(1));

    for (int i = 1; i < plan.length; i++) {
      expect(plan[i - 1].improvement, greaterThanOrEqualTo(plan[i].improvement));
    }
    expect(plan.map((r) => r.objectId).toSet().length, plan.length);
  });

  test('a fragile item under a heavy one is resolved and explained', () {
    final Structure structure = structureOf([
      [item('jar', weightKg: 0.9, fragility: Fragility.fragile)],
      [item('toolbox', weightKg: 30)],
    ], capacityKg: 25);

    final List<Rearrangement> plan = RearrangementPlanner.plan(structure);
    expect(plan, isNotEmpty);

    final Structure applied = RearrangementPlanner.apply(structure, plan.first);
    final StabilityReport after = StabilityAnalyzer.analyse(applied);

    expect(
      after.findings.map((f) => f.kind),
      isNot(contains(FindingKind.fragileUnderHeavy)),
    );
    expect(plan.first.reason, isNotEmpty);
  });

  test('a sideways shift is offered when the load leans and levels cannot change', () {
    // A single level means no move or swap is possible, so the only lever left is
    // which third of the level the object stands in. The object is tall relative
    // to the structure, which is what puts its centre of mass high enough for the
    // lean to matter.
    final Structure structure = structureOf([
      [item('toolbox', weightKg: 9.8, heightCm: 50, slot: LevelSlot.left)],
    ], heightCm: 60);

    final StabilityReport before = StabilityAnalyzer.analyse(structure);
    expect(before.status.needsAttention, isTrue);

    final List<Rearrangement> plan = RearrangementPlanner.plan(structure);
    expect(plan.single.kind, RearrangementKind.shift);
    expect(plan.single.targetSlot, LevelSlot.centre);
  });

  test('planning a large layout stays responsive', () {
    final Structure structure = structureOf([
      for (int level = 0; level < 10; level++)
        [for (int i = 0; i < 3; i++) item('o.$level.$i', weightKg: 1 + level * 0.7)],
    ], capacityKg: 30);

    final Stopwatch stopwatch = Stopwatch()..start();
    RearrangementPlanner.plan(structure);
    stopwatch.stop();

    // Thirty objects across ten levels is the heaviest case the specification
    // describes, and it runs on every edit, so it has to stay well inside a frame
    // budget on a real device.
    expect(stopwatch.elapsedMilliseconds, lessThan(400));
  });
}
