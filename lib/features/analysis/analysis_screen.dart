import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/stability_rail.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:cluckfall_heights/features/builder/builder_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The full analysis: the three measurements, the load per level, and every
/// finding with the numbers behind it.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({required this.structureId, super.key});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final StabilityReport report = state.report;
    final MeasurementSystem units = ref.watch(preferencesProvider).units;
    final AppPalette palette = context.palette;

    if (report.isEmpty) {
      return AppPage(
        title: 'Analysis',
        subtitle: state.structure.name,
        showBack: true,
        child: EmptyState(
          icon: LucideIcons.scale,
          title: 'Nothing to analyse yet',
          message: 'Place a few objects in the plan and the numbers will appear here.',
          actionLabel: 'Back to the plan',
          onAction: () => context.pop(),
        ),
      );
    }

    return AppPage(
      title: 'Analysis',
      subtitle: state.structure.name,
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShelfCard(
              accent: report.status.ink(palette),
              raised: true,
              child: Row(
                children: [
                  StabilityRail(status: report.status, height: 130, showLabel: false),
                  const SizedBox(width: Insets.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(status: report.status),
                        const SizedBox(height: Insets.md),
                        Text(
                          report.status.summary,
                          style: AppTypography.body.copyWith(color: palette.textSecondary),
                        ),
                        const SizedBox(height: Insets.md),
                        Text(
                          'This is an approximation from the sizes and weights you '
                          'entered, meant as a planning aid.',
                          style: AppTypography.caption.copyWith(color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Centre of mass'),
            ShelfCard(
              showTrim: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Height',
                          value: percent(report.centreOfMassHeight),
                          caption: _heightNote(report),
                          tint: report.centreOfMassHeight >= StabilityThresholds.topHeavyCaution
                              ? palette.caution
                              : null,
                        ),
                      ),
                      Expanded(
                        child: MetricTile(
                          label: 'Sideways',
                          value: _sidewaysValue(report),
                          caption: _sidewaysNote(report),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  _BalanceBar(offset: report.centreOfMassX),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Weight distribution'),
            ShelfCard(
              showTrim: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Total',
                          value: units.weight(report.totalWeightKg),
                          caption:
                              '${report.objectCount} '
                              '${report.objectCount == 1 ? 'item' : 'items'}',
                        ),
                      ),
                      Expanded(
                        child: MetricTile(
                          label: 'Upper half',
                          value: percent(report.upperHalfShare),
                          caption: 'of the total weight',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  for (int i = report.levelLoads.length - 1; i >= 0; i--)
                    _LevelBar(
                      load: report.levelLoads[i],
                      units: units,
                      heaviest: i == report.levelIndexWithMostWeight,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),

            SectionLabel(
              report.findings.isEmpty
                  ? 'Findings'
                  : 'Findings  (${report.findings.length})',
            ),
            if (report.findings.isEmpty)
              ShelfCard(
                accent: palette.stable,
                showTrim: false,
                child: Row(
                  children: [
                    Icon(LucideIcons.check, size: 19, color: palette.stable),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'Nothing to flag. The weight is spread reasonably and no fragile '
                        'item is at risk.',
                        style: AppTypography.caption.copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final Finding finding in report.findings)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: ShelfCard(
                    accent: finding.severity.ink(palette),
                    showTrim: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                finding.kind.title,
                                style: AppTypography.bodyStrong.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge(status: finding.severity, compact: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          finding.message,
                          style: AppTypography.caption.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),

            if (state.hasSuggestions) ...[
              const SizedBox(height: Insets.lg),
              AppButton(
                label: 'See suggested changes',
                icon: LucideIcons.wand,
                onPressed: () => context.push('/plans/$structureId/rearrange'),
              ),
            ],
            const SizedBox(height: Insets.xxxl),
          ],
        ),
      ),
    );
  }

  static String _heightNote(StabilityReport report) {
    if (report.centreOfMassHeight >= StabilityThresholds.topHeavyUnstable) {
      return 'higher than it should be';
    }
    if (report.centreOfMassHeight >= StabilityThresholds.topHeavyCaution) {
      return 'a little high';
    }
    return 'comfortably low';
  }

  static String _sidewaysValue(StabilityReport report) {
    final int offset = (report.centreOfMassX.abs() * 100).round();
    if (offset < 3) return 'Centred';
    return '$offset% ${report.centreOfMassX < 0 ? 'left' : 'right'}';
  }

  static String _sidewaysNote(StabilityReport report) {
    if (report.tippingIndex >= StabilityThresholds.tippingUnstable) {
      return 'off centre and high up';
    }
    if (report.tippingIndex >= StabilityThresholds.tippingCaution) {
      return 'worth evening out';
    }
    return 'not a concern here';
  }
}

/// Where the mass sits across the width, drawn as the base of the structure.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.offset});

  final double offset;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double centre = constraints.maxWidth / 2;
        final double x = centre * (1 + offset.clamp(-1.0, 1.0));

        return SizedBox(
          height: 34,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 15,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.railTrack,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: const SizedBox(height: 5),
                ),
              ),
              Positioned(
                left: centre - 1,
                top: 8,
                child: Container(width: 2, height: 19, color: palette.hairline),
              ),
              Positioned(
                left: (x - 9).clamp(0.0, constraints.maxWidth - 18),
                top: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.surface, width: 2.5),
                    boxShadow: Elevations.card(palette),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.load, required this.units, required this.heaviest});

  final LevelLoad load;
  final MeasurementSystem units;
  final bool heaviest;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double fraction = load.capacityUse.clamp(0.0, 1.0);
    final Color fill = load.isOverloaded
        ? palette.unstable
        : heaviest
        ? palette.accent
        : palette.shelfEdge.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${load.levelNumber}',
              style: AppTypography.numeric.copyWith(fontSize: 12, color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.railTrack,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: const SizedBox(height: 14, width: double.infinity),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    child: const SizedBox(height: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          SizedBox(
            width: 62,
            child: Text(
              units.weight(load.weightKg),
              textAlign: TextAlign.right,
              style: AppTypography.numeric.copyWith(
                fontSize: 12,
                color: load.isOverloaded ? palette.unstable : palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
