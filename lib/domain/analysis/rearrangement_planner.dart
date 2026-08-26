import 'dart:math' as math;

import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';

/// Proposes moves for objects the user already placed.
///
/// The approach is deliberately plain: build every single-step change that is
/// worth considering, run the real analyser on each, and keep the ones that
/// measurably improve the result. Nothing is guessed and nothing is hard-coded
/// per situation, so a suggestion can always be justified by the same numbers
/// the user sees on the analysis screen.
abstract final class RearrangementPlanner {
  /// Smallest score gain worth interrupting the user for.
  static const double _minimumImprovement = 2;

  /// How many suggestions to surface. More than a handful is noise.
  static const int _maxSuggestions = 5;

  /// Whether the app should offer suggestions at all.
  ///
  /// A stable layout is left alone. Constantly proposing marginal changes to a
  /// layout that is already fine is what makes a tool feel pushy.
  static bool shouldSuggest(StabilityReport report) {
    if (report.isEmpty) return false;
    if (report.status.needsAttention) return true;
    return report.levelLoads.any((l) => l.isOverloaded);
  }

  static List<Rearrangement> plan(Structure structure) {
    final StabilityReport before = StabilityAnalyzer.analyse(structure);
    if (!shouldSuggest(before)) return const [];

    final double baseScore = score(before);
    final List<Rearrangement> candidates = [];

    for (final _Candidate candidate in _candidates(structure)) {
      final StabilityReport after = StabilityAnalyzer.analyse(candidate.structure);
      final double gain = baseScore - score(after);
      if (gain < _minimumImprovement) continue;
      if (after.status.index > before.status.index) continue;

      candidates.add(
        Rearrangement(
          kind: candidate.kind,
          reason: _explain(before, after, candidate),
          resultingStatus: after.status,
          improvement: gain,
          objectId: candidate.object.id,
          objectName: candidate.object.name,
          targetLevelIndex: candidate.targetLevelIndex,
          targetSlot: candidate.targetSlot,
          partnerObjectId: candidate.partner?.id,
          partnerObjectName: candidate.partner?.name,
          partnerLevelIndex: candidate.partnerLevelIndex,
        ),
      );
    }

    candidates.sort((a, b) => b.improvement.compareTo(a.improvement));

    // One suggestion per object, so the list reads as distinct advice rather
    // than five variations on moving the same box.
    final Set<String> seen = {};
    final List<Rearrangement> result = [];
    for (final Rearrangement candidate in candidates) {
      if (!seen.add(candidate.objectId)) continue;
      result.add(candidate);
      if (result.length == _maxSuggestions) break;
    }
    return result;
  }

  /// Applies a suggestion, returning the changed structure.
  static Structure apply(Structure structure, Rearrangement rearrangement) {
    return switch (rearrangement.kind) {
      RearrangementKind.move => structure.withObjectMoved(
        rearrangement.objectId,
        rearrangement.targetLevelIndex!,
      ),
      RearrangementKind.swap => structure.withObjectsSwapped(
        rearrangement.objectId,
        rearrangement.partnerObjectId!,
      ),
      RearrangementKind.shift => structure.withObjectSlotChanged(
        rearrangement.objectId,
        rearrangement.targetSlot!,
      ),
    };
  }

  /// Penalty score for a layout. Lower is better.
  ///
  /// Continuous rather than derived from the status alone, so that a move which
  /// improves a layout without changing its status still registers as progress.
  static double score(StabilityReport report) {
    double total = 0;

    total +=
        math.max(0, report.centreOfMassHeight - StabilityThresholds.topHeavyCaution) * 200;
    total += report.tippingIndex * 120;

    for (final LevelLoad load in report.levelLoads) {
      total += math.max(0, load.capacityUse - 1) * 80;
    }

    for (final Finding finding in report.findings) {
      final double weight = finding.severity == StabilityStatus.unstable ? 30 : 10;
      total += weight * (6 - finding.kind.priority) / 5;
    }

    return total;
  }

  static Iterable<_Candidate> _candidates(Structure structure) {
    final List<_Candidate> candidates = [];

    for (int level = 0; level < structure.levels.length; level++) {
      for (final PlacedObject object in structure.levels[level].objects) {
        for (int target = 0; target < structure.levels.length; target++) {
          if (target == level) continue;
          candidates.add(
            _Candidate(
              kind: RearrangementKind.move,
              structure: structure.withObjectMoved(object.id, target),
              object: object,
              sourceLevelIndex: level,
              targetLevelIndex: target,
            ),
          );
        }

        for (final LevelSlot slot in LevelSlot.values) {
          if (slot == object.slot) continue;
          candidates.add(
            _Candidate(
              kind: RearrangementKind.shift,
              structure: structure.withObjectSlotChanged(object.id, slot),
              object: object,
              sourceLevelIndex: level,
              targetSlot: slot,
            ),
          );
        }
      }
    }

    // Swaps only make sense between objects of clearly different weight; two
    // similar items trading places changes nothing worth suggesting.
    for (int level = 0; level < structure.levels.length; level++) {
      for (final PlacedObject object in structure.levels[level].objects) {
        for (int other = level + 1; other < structure.levels.length; other++) {
          for (final PlacedObject partner in structure.levels[other].objects) {
            final double heavier = math.max(object.weightKg, partner.weightKg);
            final double lighter = math.min(object.weightKg, partner.weightKg);
            if (heavier < lighter * 2 || heavier - lighter < 0.5) continue;

            candidates.add(
              _Candidate(
                kind: RearrangementKind.swap,
                structure: structure.withObjectsSwapped(object.id, partner.id),
                object: object,
                sourceLevelIndex: level,
                partner: partner,
                partnerLevelIndex: other,
              ),
            );
          }
        }
      }
    }

    return candidates;
  }

  /// Explains a suggestion by naming the problem it removes.
  ///
  /// Preference goes to a finding that disappears, because that is the concrete
  /// thing the user was warned about. Only when nothing disappears does this fall
  /// back to describing the measurement that improved.
  static String _explain(StabilityReport before, StabilityReport after, _Candidate candidate) {
    final Set<String> afterKeys = after.findings.map(_findingKey).toSet();
    final Iterable<Finding> resolved = before.findings.where(
      (f) => !afterKeys.contains(_findingKey(f)),
    );

    if (resolved.isNotEmpty) {
      final Finding fixed = resolved.reduce(
        (a, b) => a.kind.priority <= b.kind.priority ? a : b,
      );
      return switch (fixed.kind) {
        FindingKind.topHeavy =>
          'Brings the centre of mass down from ${_percent(before.centreOfMassHeight)} to '
              '${_percent(after.centreOfMassHeight)} of the height.',
        FindingKind.fragileUnderHeavy =>
          'Takes the fragile item out from under the heavy one.',
        FindingKind.fragileOnOverloadedLevel =>
          'Gets the fragile item off the overloaded level.',
        FindingKind.tippingRisk => 'Evens the load out across the width.',
        FindingKind.levelOverloaded =>
          'Brings level ${fixed.levelNumber} back within its assumed capacity.',
        FindingKind.weightConcentrated =>
          'Spreads the weight that was concentrated on level ${fixed.levelNumber}.',
        FindingKind.levelWidthExceeded =>
          'Frees up room on level ${fixed.levelNumber}.',
        FindingKind.levelHeightExceeded =>
          'Puts the item where there is enough clearance above it.',
      };
    }

    if (after.centreOfMassHeight < before.centreOfMassHeight - 0.01) {
      return 'Lowers the centre of mass from ${_percent(before.centreOfMassHeight)} to '
          '${_percent(after.centreOfMassHeight)} of the height.';
    }
    if (after.tippingIndex < before.tippingIndex - 0.01) {
      return 'Balances the load more evenly across the width.';
    }
    return candidate.kind == RearrangementKind.swap
        ? 'Puts the heavier item lower down.'
        : 'Evens out how the weight is distributed.';
  }

  static String _findingKey(Finding finding) =>
      '${finding.kind.name}|${finding.levelIndex}|${finding.objectId}';

  static String _percent(double fraction) => '${(fraction * 100).round()}%';
}

class _Candidate {
  const _Candidate({
    required this.kind,
    required this.structure,
    required this.object,
    required this.sourceLevelIndex,
    this.targetLevelIndex,
    this.targetSlot,
    this.partner,
    this.partnerLevelIndex,
  });

  final RearrangementKind kind;
  final Structure structure;
  final PlacedObject object;
  final int sourceLevelIndex;
  final int? targetLevelIndex;
  final LevelSlot? targetSlot;
  final PlacedObject? partner;
  final int? partnerLevelIndex;
}
