import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Home: everything the user has planned, with the one thing worth acting on
/// pulled to the top.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Structure> structures = ref.watch(structuresProvider);
    final AppPreferences preferences = ref.watch(preferencesProvider);
    final AppPalette palette = context.palette;

    final List<(Structure, StabilityReport)> analysed = [
      for (final Structure structure in structures)
        (structure, StabilityAnalyzer.analyse(structure)),
    ];
    final Iterable<(Structure, StabilityReport)> needAttention = analysed.where(
      (pair) => pair.$2.status.needsAttention,
    );

    return AppPage(
      title: 'Your plans',
      subtitle: structures.isEmpty
          ? 'Plan how things stack before you move them.'
          : _summaryLine(analysed),
      actions: [
        CircleAction(
          icon: LucideIcons.plus,
          tooltip: 'New plan',
          onTap: () {
            ref.read(feedbackProvider).tap();
            context.push('/plans/new');
          },
        ),
      ],
      child: structures.isEmpty
          ? EmptyState(
              icon: LucideIcons.layoutList,
              title: 'Nothing planned yet',
              message:
                  'Create a shelf, cabinet or box, add the things you want to store, and the '
                  'app will show you how the weight sits.',
              actionLabel: 'Create your first plan',
              onAction: () => context.push('/plans/new'),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (needAttention.isNotEmpty) ...[
                    const SectionLabel('Worth a look'),
                    for (final (Structure structure, StabilityReport report) in needAttention)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: _AttentionCard(
                          structure: structure,
                          report: report,
                          onOpen: () => context.push('/plans/${structure.id}'),
                        ),
                      ),
                    const SizedBox(height: Insets.lg),
                  ],
                  SectionLabel('All plans  (${structures.length})'),
                  for (final (Structure structure, StabilityReport report) in analysed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: _PlanCard(
                        structure: structure,
                        report: report,
                        preferences: preferences,
                        onOpen: () {
                          ref.read(feedbackProvider).screenOpen();
                          context.push('/plans/${structure.id}');
                        },
                      ),
                    ),
                  const SizedBox(height: Insets.sm),
                  AppButton(
                    label: 'New plan',
                    icon: LucideIcons.plus,
                    kind: AppButtonKind.secondary,
                    onPressed: () => context.push('/plans/new'),
                  ),
                  const SizedBox(height: Insets.xxxl),
                  Text(
                    'Everything here is stored on this device only.',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
    );
  }

  static String _summaryLine(List<(Structure, StabilityReport)> analysed) {
    final int objects = analysed.fold<int>(0, (sum, pair) => sum + pair.$1.objectCount);
    final int flagged = analysed.where((pair) => pair.$2.status.needsAttention).length;
    final String plans = analysed.length == 1 ? '1 plan' : '${analysed.length} plans';
    final String items = objects == 1 ? '1 item' : '$objects items';
    return flagged == 0
        ? '$plans, $items, all looking stable.'
        : '$plans, $items, $flagged need a look.';
  }
}

/// The single most important problem across a flagged plan.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.structure,
    required this.report,
    required this.onOpen,
  });

  final Structure structure;
  final StabilityReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Finding? finding = report.primaryFinding;

    return ShelfCard(
      accent: report.status.ink(palette),
      onTap: onOpen,
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  structure.name,
                  style: AppTypography.title.copyWith(color: palette.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(status: report.status),
            ],
          ),
          if (finding != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              finding.kind.title,
              style: AppTypography.bodyStrong.copyWith(color: report.status.ink(palette)),
            ),
            const SizedBox(height: 2),
            Text(
              finding.message,
              style: AppTypography.caption.copyWith(color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.structure,
    required this.report,
    required this.preferences,
    required this.onOpen,
  });

  final Structure structure;
  final StabilityReport report;
  final AppPreferences preferences;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final String levels = structure.levels.length == 1
        ? '1 level'
        : '${structure.levels.length} levels';

    return ShelfCard(
      accent: report.isEmpty ? palette.hairline : report.status.ink(palette),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  structure.name,
                  style: AppTypography.title.copyWith(color: palette.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  report.isEmpty
                      ? '${structure.type.label} · $levels · empty'
                      : '${structure.type.label} · $levels · '
                            '${preferences.units.weight(report.totalWeightKg)}',
                  style: AppTypography.caption.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          if (!report.isEmpty) StatusBadge(status: report.status, compact: true),
          const SizedBox(width: Insets.md),
          Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
        ],
      ),
    );
  }
}
