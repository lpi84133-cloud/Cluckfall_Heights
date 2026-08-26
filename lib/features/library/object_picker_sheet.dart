import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_chip.dart';
import 'package:cluckfall_heights/core/widgets/favorite_badge.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/domain/insights/shelf_favorites.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:cluckfall_heights/features/builder/builder_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Picks an object to place, aimed at the level and zone already in focus.
///
/// A sheet rather than a separate screen: the drawing stays visible above it, so
/// the user can see where the item is about to land while choosing it.
class ObjectPickerSheet extends ConsumerStatefulWidget {
  const ObjectPickerSheet({required this.structureId, super.key});

  final String structureId;

  @override
  ConsumerState<ObjectPickerSheet> createState() => _ObjectPickerSheetState();
}

class _ObjectPickerSheetState extends ConsumerState<ObjectPickerSheet> {
  ObjectCategory? _category;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<StorageObject> library = ref.watch(objectLibraryProvider);
    final BuilderState state = ref.watch(builderProvider(widget.structureId));
    final MeasurementSystem units = ref.watch(preferencesProvider).units;
    final Map<String, int> placementCounts = ref.watch(objectPlacementCountsProvider);

    final List<StorageObject> visible = _category == null
        ? library
        : library.where((o) => o.category == _category).toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to level ${state.focusedLevelIndex + 1}',
                  style: AppTypography.heading.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${state.focusedSlot.label} zone. Tap a level in the plan to aim somewhere '
                  'else.',
                  style: AppTypography.caption.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              children: [
                AppChip(
                  label: 'All',
                  selected: _category == null,
                  count: library.length,
                  onSelected: () => setState(() => _category = null),
                ),
                for (final ObjectCategory category in ObjectCategory.values)
                  if (library.any((o) => o.category == category))
                    Padding(
                      padding: const EdgeInsets.only(left: Insets.sm),
                      child: AppChip(
                        label: category.label,
                        selected: _category == category,
                        count: library.where((o) => o.category == category).length,
                        onSelected: () => setState(() => _category = category),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xxl),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Insets.md,
                crossAxisSpacing: Insets.md,
                childAspectRatio: 0.92,
              ),
              itemCount: visible.length + 1,
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return _NewProfileTile(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/library/new');
                    },
                  );
                }
                final StorageObject object = visible[index];
                return _ObjectCard(
                  object: object,
                  units: units,
                  placements: placementCounts[object.id] ?? 0,
                  onTap: () {
                    ref.read(feedbackProvider).objectPlaced();
                    ref.read(builderProvider(widget.structureId).notifier).place(object);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({
    required this.object,
    required this.units,
    required this.onTap,
    this.placements = 0,
  });

  final StorageObject object;
  final MeasurementSystem units;
  final VoidCallback onTap;

  /// Times this profile has been placed across every saved plan, used to
  /// decide whether it has earned a [FavoriteBadge].
  final int placements;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ShelfFavoriteTier tier = ShelfFavorites.tierFor(placements);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: Corners.card,
              border: Border.all(color: palette.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: object.artAsset != null
                          ? Image.asset(object.artAsset!, fit: BoxFit.contain)
                          : Icon(LucideIcons.package, size: 34, color: palette.textTertiary),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    object.name,
                    style: AppTypography.caption.copyWith(color: palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        units.weight(object.weightKg),
                        style: AppTypography.numeric.copyWith(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      if (object.fragility.needsProtection) ...[
                        const SizedBox(width: 5),
                        Icon(
                          LucideIcons.triangleAlert,
                          size: 12,
                          color: object.fragility == Fragility.fragile
                              ? palette.unstable
                              : palette.caution,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (tier.earned)
            Positioned(top: Insets.sm, right: Insets.sm, child: FavoriteBadge(tier: tier)),
        ],
      ),
    );
  }
}

class _NewProfileTile extends StatelessWidget {
  const _NewProfileTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: Corners.card,
          border: Border.all(color: palette.hairline),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 26, color: palette.textSecondary),
              const SizedBox(height: Insets.sm),
              Text(
                'Your own object',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Library tab: the same catalogue, browsable on its own.
class ObjectLibraryScreen extends ConsumerStatefulWidget {
  const ObjectLibraryScreen({super.key});

  @override
  ConsumerState<ObjectLibraryScreen> createState() => _ObjectLibraryScreenState();
}

class _ObjectLibraryScreenState extends ConsumerState<ObjectLibraryScreen> {
  ObjectCategory? _category;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<StorageObject> library = ref.watch(objectLibraryProvider);
    final MeasurementSystem units = ref.watch(preferencesProvider).units;
    final Map<String, int> placementCounts = ref.watch(objectPlacementCountsProvider);
    final int custom = library.where((o) => !o.builtIn).length;

    final List<StorageObject> visible = _category == null
        ? library
        : library.where((o) => o.category == _category).toList(growable: false);

    return AppPage(
      title: 'Object library',
      subtitle: custom == 0
          ? '${library.length} objects. Add your own to match what you really store.'
          : '${library.length} objects, $custom of them yours.',
      actions: [
        CircleAction(
          icon: LucideIcons.plus,
          tooltip: 'New object',
          onTap: () => context.push('/library/new'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip(
                    label: 'All',
                    selected: _category == null,
                    count: library.length,
                    onSelected: () => setState(() => _category = null),
                  ),
                  for (final ObjectCategory category in ObjectCategory.values)
                    if (library.any((o) => o.category == category))
                      Padding(
                        padding: const EdgeInsets.only(left: Insets.sm),
                        child: AppChip(
                          label: category.label,
                          selected: _category == category,
                          count: library.where((o) => o.category == category).length,
                          onSelected: () => setState(() => _category = category),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Insets.md,
                crossAxisSpacing: Insets.md,
                childAspectRatio: 0.92,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) => _ObjectCard(
                object: visible[index],
                units: units,
                placements: placementCounts[visible[index].id] ?? 0,
                onTap: () => context.push('/library/${visible[index].id}'),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'Weights are ordinary household estimates. Adjust any of them to match yours.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: palette.textTertiary),
            ),
            const SizedBox(height: Insets.xxxl * 2),
          ],
        ),
      ),
    );
  }
}
