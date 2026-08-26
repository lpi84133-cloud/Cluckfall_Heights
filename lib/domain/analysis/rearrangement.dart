import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:meta/meta.dart';

enum RearrangementKind { move, swap, shift }

/// One proposed change to an existing layout.
///
/// The planner never invents objects and never deletes them: every suggestion is
/// a move of something the user already placed. Applying one is always the
/// user's decision, so a suggestion carries both the reason and the measured
/// outcome, and nothing happens until it is accepted.
@immutable
class Rearrangement {
  const Rearrangement({
    required this.kind,
    required this.reason,
    required this.resultingStatus,
    required this.improvement,
    required this.objectId,
    required this.objectName,
    this.targetLevelIndex,
    this.targetSlot,
    this.partnerObjectId,
    this.partnerObjectName,
    this.partnerLevelIndex,
  });

  final RearrangementKind kind;

  /// Plain-language explanation of what this achieves.
  final String reason;

  /// Status the layout would have after applying this.
  final StabilityStatus resultingStatus;

  /// Drop in the penalty score, higher is better. Used only for ranking.
  final double improvement;

  final String objectId;
  final String objectName;

  final int? targetLevelIndex;
  final LevelSlot? targetSlot;

  final String? partnerObjectId;
  final String? partnerObjectName;
  final int? partnerLevelIndex;

  String get title => switch (kind) {
    RearrangementKind.move => 'Move $objectName to level ${targetLevelIndex! + 1}',
    RearrangementKind.swap => 'Swap $objectName with $partnerObjectName',
    RearrangementKind.shift => 'Shift $objectName to the ${targetSlot!.label.toLowerCase()}',
  };
}
