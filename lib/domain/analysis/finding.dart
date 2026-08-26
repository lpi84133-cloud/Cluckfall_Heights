import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:meta/meta.dart';

/// What the analysis noticed.
///
/// [priority] follows the order the specification asks for, so that the builder
/// screen can show the single most important problem and leave the rest to the
/// analysis screen. Lower is more important.
enum FindingKind {
  topHeavy,
  fragileUnderHeavy,
  tippingRisk,
  fragileOnOverloadedLevel,
  levelOverloaded,
  weightConcentrated,
  levelWidthExceeded,
  levelHeightExceeded;

  int get priority => switch (this) {
    FindingKind.topHeavy => 1,
    FindingKind.fragileUnderHeavy => 2,
    FindingKind.fragileOnOverloadedLevel => 2,
    FindingKind.tippingRisk => 3,
    FindingKind.levelOverloaded => 4,
    FindingKind.weightConcentrated => 5,
    FindingKind.levelWidthExceeded => 5,
    FindingKind.levelHeightExceeded => 5,
  };

  String get title => switch (this) {
    FindingKind.topHeavy => 'Weight sits high up',
    FindingKind.fragileUnderHeavy => 'Fragile item under something heavy',
    FindingKind.tippingRisk => 'Load leans to one side',
    FindingKind.fragileOnOverloadedLevel => 'Fragile item on a loaded level',
    FindingKind.levelOverloaded => 'Level over its capacity',
    FindingKind.weightConcentrated => 'Weight concentrated on one level',
    FindingKind.levelWidthExceeded => 'Level is wider than the structure',
    FindingKind.levelHeightExceeded => 'Item taller than the space above it',
  };
}

@immutable
class Finding {
  const Finding({
    required this.kind,
    required this.severity,
    required this.message,
    this.levelIndex,
    this.objectId,
    this.relatedObjectId,
  });

  final FindingKind kind;
  final StabilityStatus severity;

  /// One sentence the user can act on. Written in plain language, with the
  /// actual measured numbers in it, because "unstable" on its own is not advice.
  final String message;

  /// Level this concerns, counted from the bottom starting at 0. Null when the
  /// finding is about the structure as a whole.
  final int? levelIndex;

  final String? objectId;

  /// The other object involved, for example the heavy item above a fragile one.
  final String? relatedObjectId;

  /// Human level number, counting from the bottom starting at 1.
  int? get levelNumber => levelIndex == null ? null : levelIndex! + 1;

  int get sortKey => kind.priority * 10 - severity.index;
}
