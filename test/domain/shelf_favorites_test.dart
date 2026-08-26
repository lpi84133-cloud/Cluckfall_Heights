import 'package:cluckfall_heights/domain/insights/shelf_favorites.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/structure_builder.dart';

/// A placement of the literal same library profile, the way the app actually
/// produces them: same [PlacedObject.sourceObjectId], different placement ids
/// because each sits in a different spot.
PlacedObject _placementOf(String sourceObjectId, String placementId) {
  return PlacedObject(
    id: placementId,
    sourceObjectId: sourceObjectId,
    name: 'Crate',
    widthCm: 20,
    depthCm: 20,
    heightCm: 20,
    weightKg: 1,
    fragility: Fragility.sturdy,
    material: ObjectMaterial.mixed,
  );
}

void main() {
  group('tier thresholds', () {
    test('below the first threshold earns nothing', () {
      expect(ShelfFavorites.tierFor(0), ShelfFavoriteTier.none);
      expect(ShelfFavorites.tierFor(ShelfFavorites.trustedAt - 1), ShelfFavoriteTier.none);
    });

    test('each threshold lands on its own tier', () {
      expect(ShelfFavorites.tierFor(ShelfFavorites.trustedAt), ShelfFavoriteTier.trusted);
      expect(ShelfFavorites.tierFor(ShelfFavorites.favoriteAt), ShelfFavoriteTier.favorite);
      expect(ShelfFavorites.tierFor(ShelfFavorites.cornerstoneAt), ShelfFavoriteTier.cornerstone);
    });

    test('tiers only ever go up with more placements', () {
      int previous = -1;
      for (int placements = 0; placements <= ShelfFavorites.cornerstoneAt + 10; placements++) {
        final int index = ShelfFavorites.tierFor(placements).index;
        expect(index, greaterThanOrEqualTo(previous));
        previous = index;
      }
    });

    test('none carries no stars and is not earned', () {
      expect(ShelfFavoriteTier.none.starCount, 0);
      expect(ShelfFavoriteTier.none.earned, isFalse);
    });

    test('every earned tier has one more star than the last', () {
      expect(ShelfFavoriteTier.trusted.starCount, 1);
      expect(ShelfFavoriteTier.favorite.starCount, 2);
      expect(ShelfFavoriteTier.cornerstone.starCount, 3);
      for (final ShelfFavoriteTier tier in ShelfFavoriteTier.values) {
        expect(tier.earned, tier != ShelfFavoriteTier.none);
      }
    });
  });

  group('placement counts', () {
    test('an empty library counts nothing', () {
      expect(ShelfFavorites.placementCounts(const []), isEmpty);
    });

    test('placements are counted per source profile, not per name', () {
      final List<Structure> structures = [
        structureOf([
          [item('a1', weightKg: 1, name: 'Jar')],
          [item('a2', weightKg: 1, name: 'Jar')],
        ], id: 'one'),
      ];

      final Map<String, int> counts = ShelfFavorites.placementCounts(structures);
      expect(counts['test.a1'], 1);
      expect(counts['test.a2'], 1);
    });

    test('placements of the same profile add up across plans', () {
      final List<Structure> structures = [
        structureOf([
          [item('x', weightKg: 1, name: 'Jar')],
        ], id: 'one'),
        structureOf([
          [item('x', weightKg: 1, name: 'Jar')],
        ], id: 'two'),
      ];

      final Map<String, int> counts = ShelfFavorites.placementCounts(structures);
      expect(counts['test.x'], 2);
    });

    test('the same profile reused enough times reaches the trusted tier', () {
      final List<Structure> structures = [
        for (int i = 0; i < ShelfFavorites.trustedAt; i++)
          structureOf([
            [_placementOf('library.crate', 'placement.$i')],
          ], id: 'plan.$i'),
      ];

      final Map<String, int> counts = ShelfFavorites.placementCounts(structures);
      expect(counts['library.crate'], ShelfFavorites.trustedAt);
      expect(ShelfFavorites.tierFor(counts['library.crate']!), ShelfFavoriteTier.trusted);
    });
  });
}
