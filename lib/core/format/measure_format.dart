import 'package:cluckfall_heights/domain/units/measurement_system.dart';

/// Formats stored metric values in whatever units the user chose.
extension MeasureFormat on MeasurementSystem {
  String length(double cm, {int decimals = 0}) {
    final double value = lengthFromCm(cm);
    return '${_trim(value, decimals)} $lengthUnit';
  }

  String weight(double kg, {int? decimals}) {
    final double value = weightFromKg(kg);
    final int places = decimals ?? (value < 10 ? 1 : 0);
    return '${_trim(value, places)} $weightUnit';
  }

  /// Number only, for places where the unit is already in a nearby label.
  String lengthValue(double cm, {int decimals = 0}) => _trim(lengthFromCm(cm), decimals);

  String weightValue(double kg, {int decimals = 1}) => _trim(weightFromKg(kg), decimals);

  static String _trim(double value, int decimals) {
    final String text = value.toStringAsFixed(decimals);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}

String percent(double fraction) => '${(fraction * 100).round()}%';
