import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:flutter/material.dart';

/// The colour used for a material wherever it is drawn.
///
/// Shared so an object block on the plan and its slice of the material
/// breakdown are recognisably the same thing. The domain enum stays free of any
/// presentation detail.
extension MaterialTint on ObjectMaterial {
  Color tint(AppPalette palette) => switch (this) {
    ObjectMaterial.wood => const Color(0xFFC89A5E),
    ObjectMaterial.metal => const Color(0xFF9AA0A6),
    ObjectMaterial.plastic => const Color(0xFF8FC0D6),
    ObjectMaterial.cardboard => const Color(0xFFCBA378),
    ObjectMaterial.glass => const Color(0xFFB6D8DC),
    ObjectMaterial.organic => const Color(0xFFE3D2AE),
    ObjectMaterial.mixed => palette.sandTone,
  };
}
