/// Which units the interface shows.
///
/// Everything is stored in centimetres and kilograms regardless of this setting.
/// Conversion happens only on the way to and from the screen, so switching the
/// setting never rewrites saved data and never loses precision.
enum MeasurementSystem {
  metric,
  imperial;

  String get lengthUnit => this == MeasurementSystem.metric ? 'cm' : 'in';

  String get weightUnit => this == MeasurementSystem.metric ? 'kg' : 'lb';

  String get label => this == MeasurementSystem.metric
      ? 'Centimetres and kilograms'
      : 'Inches and pounds';

  double lengthFromCm(double cm) => this == MeasurementSystem.metric ? cm : cm / 2.54;

  double lengthToCm(double value) => this == MeasurementSystem.metric ? value : value * 2.54;

  double weightFromKg(double kg) => this == MeasurementSystem.metric ? kg : kg * 2.2046226218;

  double weightToKg(double value) => this == MeasurementSystem.metric ? value : value / 2.2046226218;
}
