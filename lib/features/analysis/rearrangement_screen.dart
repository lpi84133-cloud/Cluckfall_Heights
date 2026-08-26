import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/stability_rail.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement_planner.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/features/builder/builder_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Suggested changes, each one applied only if the user says so.
///
/// Every card states the move, the reason, and what the status becomes afterwards.
/// Nothing is applied automatically, and anything applied can be undone from the
/// plan, so a suggestion is never able to quietly ruin someone's layout.
class RearrangementScreen extends ConsumerWidget {
  const RearrangementScreen({required this.structureId, super.key});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final AppPalette palette = context.palette;
    final List<Rearrangement> suggestions = RearrangementPlanner.plan(state.structure);

    return AppPage(
      title: 'Suggestions',
      subtitle: state.structure.name,
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (suggestions.isEmpty)
              EmptyState(
                icon: LucideIcons.check,
                title: state.report.isEmpty
                    ? 'Nothing to suggest yet'
                    : 'No changes worth making',
                message: state.report.isEmpty
                    ? 'Place a few objects and any useful moves will show up here.'
                    : 'The layout already reads as sound. Suggestions come back if you '
                          'add something heavy or move things around.',
                actionLabel: 'Back to the plan',
                onAction: () => context.pop(),
              )
            else ...[
              ShelfCard(
                accent: state.report.status.ink(palette),
                showTrim: false,
                child: Row(
                  children: [
                    StatusBadge(status: state.report.status, compact: true),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        suggestions.length == 1
                            ? 'One change would help. Review it below.'
                            : '${suggestions.length} changes would help, best first.',
                        style: AppTypography.caption.copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              for (int i = 0; i < suggestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: _SuggestionCard(
                    suggestion: suggestions[i],
                    rank: i,
                    before: state.report,
                    outcome: StabilityAnalyzer.analyse(
                      RearrangementPlanner.apply(state.structure, suggestions[i]),
                    ),
                    onApply: () async {
                      await ref.read(feedbackProvider).objectPlaced();
                      ref
                          .read(builderProvider(structureId).notifier)
                          .applySuggestion(suggestions[i]);
                    },
                  ),
                ),
              const SizedBox(height: Insets.sm),
              Text(
                'Applying a change updates the plan straight away. Undo is in the top bar '
                'of the plan.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
            ],
            const SizedBox(height: Insets.xxxl),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.rank,
    required this.before,
    required this.outcome,
    required this.onApply,
  });

  final Rearrangement suggestion;
  final int rank;

  /// The plan as it stands right now, so the card can show what changes
  /// rather than only what the result would be.
  final StabilityReport before;
  final StabilityReport outcome;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return ShelfCard(
      accent: rank == 0 ? palette.accent : palette.hairline,
      raised: rank == 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: rank == 0 ? palette.accent : palette.surfaceSunken,
                  borderRadius: const BorderRadius.all(Radius.circular(Corners.sm)),
                ),
                child: Icon(
                  suggestion.kind.icon,
                  size: 16,
                  color: rank == 0 ? palette.accentInk : palette.textSecondary,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: AppTypography.title.copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            suggestion.reason,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: Insets.lg),
          _BeforeAfter(before: before.status, after: outcome.status),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              const Spacer(),
              AppButton(
                label: 'Apply',
                kind: AppButtonKind.quiet,
                onPressed: onApply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Side-by-side gauges showing the plan's status right now against what it
/// would become, so the benefit of a suggestion is seen rather than taken on
/// faith from the reason text alone.
class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.before, required this.after});

  final StabilityStatus before;
  final StabilityStatus after;

  static const double _railHeight = 76;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: const BorderRadius.all(Radius.circular(Corners.sm)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: [
            Expanded(child: _RailColumn(label: 'Now', status: before, height: _railHeight)),
            Icon(LucideIcons.arrowRight, size: 16, color: palette.textTertiary),
            Expanded(
              child: _RailColumn(label: 'After', status: after, height: _railHeight),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailColumn extends StatelessWidget {
  const _RailColumn({required this.label, required this.status, required this.height});

  final String label;
  final StabilityStatus status;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.overline.copyWith(color: palette.textTertiary),
        ),
        const SizedBox(height: Insets.xs),
        StabilityRail(status: status, showLabel: false, height: height),
      ],
    );
  }
}

extension _RearrangementIcon on RearrangementKind {
  IconData get icon => switch (this) {
    RearrangementKind.move => LucideIcons.arrowDown,
    RearrangementKind.swap => LucideIcons.arrowUpDown,
    RearrangementKind.shift => LucideIcons.arrowLeftRight,
  };
}
