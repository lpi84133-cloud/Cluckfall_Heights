import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/theme/material_tint.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/insights/portfolio_insights.dart';
import 'package:cluckfall_heights/domain/insights/storage_guide.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Everything planned so far, read across plans rather than one at a time.
///
/// The builder answers whether one shelf is sound. This answers the questions
/// that only appear once there is more than one plan: how much is stored in
/// total, what it is made of, how much room is left, and what to read next.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PortfolioInsights insights = ref.watch(insightsProvider);
    final MeasurementSystem units = ref.watch(
      preferencesProvider.select((AppPreferences p) => p.units),
    );

    return AppPage(
      title: 'Insights',
      subtitle: insights.isEmpty
          ? 'Reference reading while you have nothing planned yet.'
          : 'Across ${_plural(insights.planCount, 'plan')}, all measured on this device.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (insights.isEmpty)
              const _NothingPlannedYet()
            else ...[
              _Totals(insights: insights, units: units),
              const SizedBox(height: Insets.xl),
              _Capacity(insights: insights, units: units),
              const SizedBox(height: Insets.xl),
              _Balance(insights: insights),
              if (insights.hasPlacements) ...[
                const SizedBox(height: Insets.xl),
                _Materials(insights: insights, units: units),
                const SizedBox(height: Insets.xl),
                _MostUsed(insights: insights, units: units),
                const SizedBox(height: Insets.xl),
                _ByPlan(insights: insights, units: units),
              ],
            ],
            const SizedBox(height: Insets.xl),
            const _GuideSection(),
          ],
        ),
      ),
    );
  }
}

String _plural(int count, String noun) => '$count $noun${count == 1 ? '' : 's'}';

// ────────────────────────────────────────────────────────────────────────────
// Empty state
// ────────────────────────────────────────────────────────────────────────────

class _NothingPlannedYet extends StatelessWidget {
  const _NothingPlannedYet();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.chartNoAxesColumn,
      title: 'Nothing measured yet',
      message:
          'Once you save a plan, this screen shows what you are storing in '
          'total, what it is made of, and how much room is left.',
      actionLabel: 'Start a plan',
      onAction: () => context.push('/plans/new'),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Totals
// ────────────────────────────────────────────────────────────────────────────

class _Totals extends StatelessWidget {
  const _Totals({required this.insights, required this.units});

  final PortfolioInsights insights;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('The totals'),
        const SizedBox(height: Insets.md),
        ShelfCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Weight planned',
                      value: units.weight(insights.totalWeightKg, decimals: 0),
                      caption: _plural(insights.objectCount, 'item'),
                    ),
                  ),
                  Expanded(
                    child: MetricTile(
                      label: 'Levels in use',
                      value: '${insights.filledLevelCount}',
                      caption: insights.emptyLevelCount == 0
                          ? 'every level filled'
                          : '${insights.emptyLevelCount} still empty',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Needing a look',
                      value: '${insights.plansNeedingWork}',
                      caption: insights.plansNeedingWork == 0
                          ? 'all plans read well'
                          : _plural(insights.findingCount, 'finding'),
                      tint: insights.plansNeedingWork == 0
                          ? palette.stable
                          : palette.caution,
                    ),
                  ),
                  Expanded(
                    child: MetricTile(
                      label: 'Needs care',
                      value: '${insights.protectedCount}',
                      caption: insights.protectedCount == 0
                          ? 'nothing breakable'
                          : '${insights.fragileCount} fragile',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Capacity headroom
// ────────────────────────────────────────────────────────────────────────────

class _Capacity extends StatelessWidget {
  const _Capacity({required this.insights, required this.units});

  final PortfolioInsights insights;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double use = insights.capacityUse;
    final bool tight = use >= 0.85;
    final Color ink = use >= 1.0
        ? palette.unstable
        : tight
        ? palette.caution
        : palette.stable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Room left'),
        const SizedBox(height: Insets.md),
        ShelfCard(
          accent: ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          units.weight(insights.headroomKg, decimals: 0),
                          style: AppTypography.metric.copyWith(color: ink),
                        ),
                        Text(
                          'still available',
                          style: AppTypography.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        percent(use),
                        style: AppTypography.numeric.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        'in use',
                        style: AppTypography.overline.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: palette.railTrack),
                      ),
                      FractionallySizedBox(
                        widthFactor: use.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: ColoredBox(color: ink),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                use >= 1.0
                    ? 'The combined load is past the assumed capacity of your '
                          'levels. Check which plans are flagged.'
                    : tight
                    ? 'Your shelves are close to the limits you set. Raising a '
                          'level capacity is fine if you know the real rating.'
                    : 'Out of ${units.weight(insights.totalCapacityKg, decimals: 0)} '
                          'of assumed capacity across ${_plural(insights.levelCount, 'level')}.',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Balance
// ────────────────────────────────────────────────────────────────────────────

class _Balance extends StatelessWidget {
  const _Balance({required this.insights});

  final PortfolioInsights insights;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double height = insights.averageCentreOfMass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('How you load'),
        const SizedBox(height: Insets.md),
        ShelfCard(
          onTap: () => context.push('/insights/guide/${StorageGuide.weightLow.id}'),
          child: Row(
            children: [
              // A miniature structure with the average mass line drawn on it.
              _MassSketch(height: height, palette: palette),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      percent(height),
                      style: AppTypography.metric.copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      'average mass height',
                      style: AppTypography.overline.copyWith(
                        color: palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    Text(
                      insights.balanceVerdict,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lower is steadier. Read why',
                      style: AppTypography.caption.copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small side-on structure with a line where the combined weight sits.
class _MassSketch extends StatelessWidget {
  const _MassSketch({required this.height, required this.palette});

  final double height;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    const double boxHeight = 64;
    final double marker = (1 - height.clamp(0.0, 1.0)) * boxHeight;

    return SizedBox(
      width: 46,
      height: boxHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: const BorderRadius.all(Radius.circular(Corners.xs)),
                border: Border.all(color: palette.hairline),
              ),
            ),
          ),
          // Shelf lines
          for (int i = 1; i < 4; i++)
            Positioned(
              left: 3,
              right: 3,
              top: boxHeight / 4 * i,
              child: Container(height: 1, color: palette.hairline),
            ),
          // Mass line
          Positioned(
            left: 0,
            right: 0,
            top: marker.clamp(1.0, boxHeight - 2),
            child: Container(height: 2, color: palette.accent),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Materials
// ────────────────────────────────────────────────────────────────────────────

class _Materials extends StatelessWidget {
  const _Materials({required this.insights, required this.units});

  final PortfolioInsights insights;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'What it is made of',
          trailing: Text(
            _plural(insights.materials.length, 'material'),
            style: AppTypography.caption.copyWith(color: palette.textTertiary),
          ),
        ),
        const SizedBox(height: Insets.md),
        ShelfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One bar, split by weight share.
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (final MaterialShare share in insights.materials)
                        Expanded(
                          flex: (share.share * 1000).round().clamp(1, 1000),
                          child: ColoredBox(color: share.material.tint(palette)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              for (final MaterialShare share in insights.materials) ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: share.material.tint(palette),
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        share.material.label,
                        style: AppTypography.body.copyWith(color: palette.textPrimary),
                      ),
                    ),
                    Text(
                      '${_plural(share.objectCount, 'item')} · '
                      '${units.weight(share.weightKg)}',
                      style: AppTypography.caption.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    SizedBox(
                      width: 34,
                      child: Text(
                        percent(share.share),
                        textAlign: TextAlign.right,
                        style: AppTypography.numeric.copyWith(
                          fontSize: 13,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (share != insights.materials.last)
                  const SizedBox(height: Insets.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Most-placed objects
// ────────────────────────────────────────────────────────────────────────────

class _MostUsed extends StatelessWidget {
  const _MostUsed({required this.insights, required this.units});

  final PortfolioInsights insights;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int most = insights.topObjects.isEmpty
        ? 1
        : insights.topObjects.first.placements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Placed most often'),
        const SizedBox(height: Insets.md),
        ShelfCard(
          child: Column(
            children: [
              for (final ObjectUsage usage in insights.topObjects) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: usage.artAsset != null
                          ? Image.asset(usage.artAsset!, fit: BoxFit.contain)
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.surfaceSunken,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(Corners.xs),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  usage.name.isEmpty
                                      ? '?'
                                      : usage.name.substring(0, 1).toUpperCase(),
                                  style: AppTypography.numeric.copyWith(
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            usage.name,
                            style: AppTypography.body.copyWith(
                              color: palette.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // Bar relative to the most-placed profile.
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                            child: SizedBox(
                              height: 4,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ColoredBox(color: palette.railTrack),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: (usage.placements / most).clamp(0.05, 1.0),
                                    alignment: Alignment.centerLeft,
                                    child: ColoredBox(color: palette.accent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${usage.placements}×',
                          style: AppTypography.numeric.copyWith(
                            fontSize: 14,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          units.weight(usage.weightKg),
                          style: AppTypography.overline.copyWith(
                            fontSize: 9,
                            letterSpacing: 0,
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (usage != insights.topObjects.last)
                  const SizedBox(height: Insets.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Per plan
// ────────────────────────────────────────────────────────────────────────────

class _ByPlan extends StatelessWidget {
  const _ByPlan({required this.insights, required this.units});

  final PortfolioInsights insights;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double heaviest = insights.plans.isEmpty
        ? 1
        : insights.plans.first.weightKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Heaviest plans'),
        const SizedBox(height: Insets.md),
        for (final PlanDigest plan in insights.plans) ...[
          ShelfCard(
            accent: plan.status == StabilityStatus.stable
                ? palette.hairline
                : plan.status.ink(palette),
            onTap: () => context.push('/plans/${plan.id}'),
            padding: const EdgeInsets.all(Insets.md + 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: AppTypography.bodyStrong.copyWith(
                                color: palette.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          StatusBadge(status: plan.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: Insets.sm),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(color: palette.railTrack),
                              ),
                              FractionallySizedBox(
                                widthFactor: heaviest <= 0
                                    ? 0
                                    : (plan.weightKg / heaviest).clamp(0.02, 1.0),
                                alignment: Alignment.centerLeft,
                                child: ColoredBox(
                                  color: plan.status == StabilityStatus.stable
                                      ? palette.accent
                                      : plan.status.ink(palette),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        '${units.weight(plan.weightKg)} · '
                        '${_plural(plan.objectCount, 'item')}'
                        '${plan.findingCount == 0 ? '' : ' · ${_plural(plan.findingCount, 'finding')}'}',
                        style: AppTypography.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (plan != insights.plans.last) const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Guide
// ────────────────────────────────────────────────────────────────────────────

class _GuideSection extends StatelessWidget {
  const _GuideSection();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Worth knowing',
          trailing: Text(
            _plural(StorageGuide.all.length, 'article'),
            style: AppTypography.caption.copyWith(color: palette.textTertiary),
          ),
        ),
        const SizedBox(height: Insets.md),
        for (final GuideArticle article in StorageGuide.all) ...[
          ShelfCard(
            onTap: () => context.push('/insights/guide/${article.id}'),
            padding: const EdgeInsets.all(Insets.md + 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        article.summary,
                        style: AppTypography.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock3,
                            size: 11,
                            color: palette.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${article.readMinutes} min read',
                            style: AppTypography.overline.copyWith(
                              fontSize: 9,
                              letterSpacing: 0.2,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
              ],
            ),
          ),
          if (article != StorageGuide.all.last) const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}
