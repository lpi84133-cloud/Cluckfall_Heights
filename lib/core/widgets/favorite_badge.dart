import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/domain/insights/shelf_favorites.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Small corner marker shown once an object profile has been placed often
/// enough to count as a shelf favourite.
///
/// Every tier reuses the same star rather than switching icon, so a badge
/// reads as "the same kind of thing, more of it": the honest way to earn a
/// second star is simply to keep using the profile.
class FavoriteBadge extends StatelessWidget {
  const FavoriteBadge({required this.tier, super.key});

  final ShelfFavoriteTier tier;

  @override
  Widget build(BuildContext context) {
    if (!tier.earned) return const SizedBox.shrink();
    final AppPalette palette = context.palette;

    return Semantics(
      label: '${tier.label} object. ${tier.description}',
      child: Tooltip(
        message: '${tier.label}: ${tier.description}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.accent,
            borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
            boxShadow: [
              BoxShadow(color: palette.shadow, blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < tier.starCount; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 1),
                    child: Icon(LucideIcons.star, size: 10, color: palette.accentInk),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
