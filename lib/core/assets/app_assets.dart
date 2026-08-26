/// Every bundled asset path in one place.
///
/// Paths are written by hand rather than generated so that a typo shows up as a
/// compile error and so the precache list used by the startup sequence can be
/// derived from the same source of truth.
library;

class ObjectArt {
  const ObjectArt._();

  static const String chicken = 'assets/img/objects/chicken.webp';
  static const String egg = 'assets/img/objects/egg.webp';
  static const String coin = 'assets/img/objects/coin.webp';
  static const String storageBox = 'assets/img/objects/storage_box.webp';
  static const String woodenShelf = 'assets/img/objects/wooden_shelf.webp';
  static const String metalShelf = 'assets/img/objects/metal_shelf.webp';
  static const String plasticContainer = 'assets/img/objects/plastic_container.webp';
  static const String cardboardBox = 'assets/img/objects/cardboard_box.webp';
  static const String bottle = 'assets/img/objects/bottle.webp';
  static const String jar = 'assets/img/objects/jar.webp';
  static const String book = 'assets/img/objects/book.webp';
  static const String toolBox = 'assets/img/objects/tool_box.webp';

  static const List<String> all = [
    chicken,
    egg,
    coin,
    storageBox,
    woodenShelf,
    metalShelf,
    plasticContainer,
    cardboardBox,
    bottle,
    jar,
    book,
    toolBox,
  ];
}

class IndicatorArt {
  const IndicatorArt._();

  /// Full three-zone capsule, used as the vertical stability rail.
  static const String stabilityGauge = 'assets/img/indicators/stability_gauge.webp';
  static const String zoneStable = 'assets/img/indicators/stability_zone_stable.webp';
  static const String zoneCaution = 'assets/img/indicators/stability_zone_caution.webp';
  static const String zoneUnstable = 'assets/img/indicators/stability_zone_unstable.webp';

  /// Badge only. The axis line is painted natively so it can span any height.
  static const String centerOfMassBadge = 'assets/img/indicators/center_of_mass_badge.webp';
  static const String centerOfMassMarker = 'assets/img/indicators/center_of_mass_marker.webp';
  static const String fragileSymbol = 'assets/img/indicators/fragile_symbol.webp';

  /// Decoration for the analysis header. Real load bars are painted from data.
  static const String weightDistributionDecor =
      'assets/img/indicators/weight_distribution_decor.webp';

  static const List<String> all = [
    stabilityGauge,
    zoneStable,
    zoneCaution,
    zoneUnstable,
    centerOfMassBadge,
    centerOfMassMarker,
    fragileSymbol,
    weightDistributionDecor,
  ];
}

class BackgroundArt {
  const BackgroundArt._();

  static const String pantry = 'assets/img/backgrounds/pantry.webp';
  static const String garage = 'assets/img/backgrounds/garage.webp';
  static const String storageRoom = 'assets/img/backgrounds/storage_room.webp';
  static const String kitchenCabinet = 'assets/img/backgrounds/kitchen_cabinet.webp';

  static const List<String> all = [pantry, garage, storageRoom, kitchenCabinet];
}

class BrandArt {
  const BrandArt._();

  static const String logo = 'assets/img/brand/logo.webp';
  static const String loadingPortrait = 'assets/img/brand/loading_portrait.webp';
  static const String loadingLandscape = 'assets/img/brand/loading_landscape.webp';

  static const List<String> all = [logo, loadingPortrait, loadingLandscape];
}

class SoundAsset {
  const SoundAsset._();

  static const String buttonTap = 'assets/sounds/button_tap.mp3';
  static const String screenOpen = 'assets/sounds/screen_open.mp3';
  static const String error = 'assets/sounds/error.mp3';
  static const String objectPlacement = 'assets/sounds/object_placement.mp3';
  static const String objectRemoval = 'assets/sounds/object_removal.mp3';
  static const String structureSaved = 'assets/sounds/structure_saved.mp3';
  static const String stabilityWarning = 'assets/sounds/stability_warning.mp3';
  static const String successfulRearrangement = 'assets/sounds/successful_rearrangement.mp3';

  static const List<String> all = [
    buttonTap,
    screenOpen,
    error,
    objectPlacement,
    objectRemoval,
    structureSaved,
    stabilityWarning,
    successfulRearrangement,
  ];
}

class LegalAsset {
  const LegalAsset._();

  static const String privacy = 'assets/legal/privacy.html';
  static const String support = 'assets/legal/support.html';

  static const String privacyUrl = 'https://cluckfallheights.com/privacy-policy.html';
  static const String supportUrl = 'https://cluckfallheights.com/support.html';
}
