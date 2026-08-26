/// The three states a layout can be in.
///
/// Ordering matters: [index] is used to compare severity, so the values must
/// stay in ascending order of concern.
enum StabilityStatus {
  stable,
  caution,
  unstable;

  String get label => switch (this) {
    StabilityStatus.stable => 'Stable',
    StabilityStatus.caution => 'Caution',
    StabilityStatus.unstable => 'Unstable',
  };

  /// One line the user can act on, shown next to the badge.
  String get summary => switch (this) {
    StabilityStatus.stable => 'Weight is spread reasonably and nothing fragile is at risk.',
    StabilityStatus.caution => 'Something here is worth a second look.',
    StabilityStatus.unstable => 'A clear problem was found in this layout.',
  };

  bool get needsAttention => this != StabilityStatus.stable;

  StabilityStatus worseOf(StabilityStatus other) => index >= other.index ? this : other;
}
