import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:meta/meta.dart';

/// How established an object profile has become, judged purely by how many
/// times it has actually been placed across every saved plan.
///
/// Three tiers rather than a raw count, because a badge is meant to be read at
/// a glance on a small card, not studied. The first tier only lands once a
/// profile has proven itself worth reusing, not on the first placement, so
/// earning one means something.
enum ShelfFavoriteTier {
  none,
  trusted,
  favorite,
  cornerstone;

  String get label => switch (this) {
    ShelfFavoriteTier.none => '',
    ShelfFavoriteTier.trusted => 'Trusted',
    ShelfFavoriteTier.favorite => 'Favourite',
    ShelfFavoriteTier.cornerstone => 'Cornerstone',
  };

  String get description => switch (this) {
    ShelfFavoriteTier.none => '',
    ShelfFavoriteTier.trusted => 'Placed on ${ShelfFavorites.trustedAt} or more shelves.',
    ShelfFavoriteTier.favorite => 'Placed on ${ShelfFavorites.favoriteAt} or more shelves.',
    ShelfFavoriteTier.cornerstone =>
      'Placed on ${ShelfFavorites.cornerstoneAt} or more shelves.',
  };

  /// One star per tier, so a higher badge visibly contains the ones below it.
  int get starCount => switch (this) {
    ShelfFavoriteTier.none => 0,
    ShelfFavoriteTier.trusted => 1,
    ShelfFavoriteTier.favorite => 2,
    ShelfFavoriteTier.cornerstone => 3,
  };

  bool get earned => this != ShelfFavoriteTier.none;
}

/// Placement counts and the milestone badges built from them.
///
/// Kept apart from [PortfolioInsights] because that aggregation is keyed by
/// object name, which is right for a portfolio-wide ranking but wrong for a
/// badge on one specific library entry: two profiles can share a name, and
/// only a placement's source id reliably says which profile it came from.
@immutable
abstract final class ShelfFavorites {
  static const int trustedAt = 5;
  static const int favoriteAt = 15;
  static const int cornerstoneAt = 30;

  static ShelfFavoriteTier tierFor(int placements) {
    if (placements >= cornerstoneAt) return ShelfFavoriteTier.cornerstone;
    if (placements >= favoriteAt) return ShelfFavoriteTier.favorite;
    if (placements >= trustedAt) return ShelfFavoriteTier.trusted;
    return ShelfFavoriteTier.none;
  }

  /// How many times each library profile has been placed, keyed by
  /// `PlacedObject.sourceObjectId`, across every saved plan.
  static Map<String, int> placementCounts(Iterable<Structure> structures) {
    final Map<String, int> counts = {};
    for (final Structure structure in structures) {
      for (final object in structure.allObjects) {
        counts[object.sourceObjectId] = (counts[object.sourceObjectId] ?? 0) + 1;
      }
    }
    return counts;
  }
}
