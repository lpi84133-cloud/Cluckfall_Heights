import 'dart:async';

import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/core/widgets/stability_rail.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/finding.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:cluckfall_heights/features/builder/builder_controller.dart';
import 'package:cluckfall_heights/features/builder/level_settings_sheet.dart';
import 'package:cluckfall_heights/features/builder/structure_canvas.dart';
import 'package:cluckfall_heights/features/library/object_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BuilderScreen extends ConsumerWidget {
  const BuilderScreen({required this.structureId, super.key});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final BuilderController controller = ref.read(builderProvider(structureId).notifier);
    final AppPreferences preferences = ref.watch(preferencesProvider);
    final AppPalette palette = context.palette;

    return AppPage(
      title: state.structure.name,
      subtitle: '${state.structure.type.label} · '
          '${preferences.units.length(state.structure.widthCm)} wide · '
          '${state.structure.levels.length} levels · '
          '${preferences.units.weight(state.report.totalWeightKg)}',
      showBack: true,
      scrollable: false,
      actions: [
        if (state.canUndo)
          CircleAction(
            icon: LucideIcons.undo2,
            tooltip: 'Undo',
            onTap: () {
              unawaited(ref.read(feedbackProvider).tap());
              controller.undo();
            },
          ),
        CircleAction(
          icon: LucideIcons.settings2,
          tooltip: 'Plan settings',
          onTap: () => _openSettings(context, ref),
        ),
      ],
      bottomBar: _ActionDock(structureId: structureId),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Height scale on the left
                  _HeightScale(structure: state.structure, units: preferences.units),
                  const SizedBox(width: Insets.sm),
                  // Main canvas
                  Expanded(
                    child: StructureCanvas(
                      structure: state.structure,
                      report: state.report,
                      selectedObjectId: state.selectedObjectId,
                      onSelectObject: controller.select,
                      onMoveObject: (object, levelIndex, slot) {
                        unawaited(ref.read(feedbackProvider).objectPlaced());
                        controller.move(object, levelIndex, slot);
                      },
                      onTapSlot: controller.focus,
                      onTapEmptyLevel: (levelIndex) async {
                        controller.focus(levelIndex, LevelSlot.centre);
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ObjectPickerSheet(structureId: structureId),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  // Stability rail on the right
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StabilityRail(status: state.report.status, height: 150),
                      const SizedBox(height: Insets.md),
                      Text(
                        percent(state.report.centreOfMassHeight),
                        style: AppTypography.numeric.copyWith(color: palette.textPrimary),
                      ),
                      Text(
                        'MASS',
                        style: AppTypography.overline.copyWith(color: palette.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          // ── Space-fill bar ──────────────────────────────────────────────
          if (!state.report.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: _SpaceFillBar(structureId: structureId, units: preferences.units),
            ),
          const SizedBox(height: Insets.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.page),
            child: state.selectedObject != null
                ? _SelectionPanel(
                    object: state.selectedObject!,
                    structureId: structureId,
                    units: preferences.units,
                  )
                : _StatusPanel(structureId: structureId),
          ),
          const SizedBox(height: Insets.md),
        ],
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    unawaited(ref.read(feedbackProvider).tap());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LevelSettingsSheet(structureId: structureId),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Height scale
// ────────────────────────────────────────────────────────────────────────────

class _HeightScale extends StatelessWidget {
  const _HeightScale({required this.structure, required this.units});

  final Structure structure;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int levels = structure.levels.length;

    return SizedBox(
      width: 34,
      child: Column(
        verticalDirection: VerticalDirection.up,
        children: [
          for (int i = 0; i < levels; i++)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${i + 1}',
                            style: AppTypography.numeric.copyWith(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                          Text(
                            units.lengthValue(structure.baseHeightOf(i)),
                            style: AppTypography.overline.copyWith(
                              fontSize: 9,
                              letterSpacing: 0,
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 5, height: 1.5, color: palette.hairline),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status panel (when nothing is selected)
// ────────────────────────────────────────────────────────────────────────────

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.structureId});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final AppPalette palette = context.palette;
    final Finding? finding = state.report.primaryFinding;

    if (state.report.isEmpty) {
      return ShelfCard(
        showTrim: false,
        padding: const EdgeInsets.all(Insets.md + 2),
        child: Row(
          children: [
            Icon(LucideIcons.hand, size: 19, color: palette.textSecondary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'Tap any level on the drawing to add an object there.',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (finding == null) {
      return ShelfCard(
        accent: palette.stable,
        padding: const EdgeInsets.all(Insets.md + 2),
        child: Row(
          children: [
            StatusBadge(status: state.report.status),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'Weight is spread reasonably. Nothing fragile is at risk.',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return ShelfCard(
      accent: state.report.status.ink(palette),
      onTap: () => context.push('/plans/$structureId/analysis'),
      padding: const EdgeInsets.all(Insets.md + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(status: state.report.status, compact: true),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        finding.kind.title,
                        style: AppTypography.bodyStrong.copyWith(
                          color: state.report.status.ink(palette),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  finding.message,
                  style: AppTypography.caption.copyWith(color: palette.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: palette.textTertiary),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Selection panel (when an object is tapped)
// ────────────────────────────────────────────────────────────────────────────

class _SelectionPanel extends ConsumerWidget {
  const _SelectionPanel({
    required this.object,
    required this.structureId,
    required this.units,
  });

  final PlacedObject object;
  final String structureId;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderController controller = ref.read(builderProvider(structureId).notifier);
    final AppPalette palette = context.palette;
    final int? level = ref
        .watch(builderProvider(structureId))
        .structure
        .levelIndexOfObject(object.id);

    return ShelfCard(
      accent: palette.accent,
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Identity row ──────────────────────────────────────────────────
          Row(
            children: [
              if (object.artAsset != null)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.md),
                  child: Image.asset(
                    object.artAsset!,
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      object.name,
                      style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level ${(level ?? 0) + 1} · ${units.weight(object.weightKg)} · ${object.fragility.label}',
                      style: AppTypography.caption.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              // Deselect ×
              GestureDetector(
                onTap: () => controller.select(null),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: palette.surfaceSunken,
                    borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
                  ),
                  child: Icon(LucideIcons.x, size: 16, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          // ── Slot chips + Remove ───────────────────────────────────────────
          Row(
            children: [
              for (final LevelSlot slot in LevelSlot.values) ...[
                _SlotChip(
                  label: slot.label,
                  selected: object.slot == slot,
                  onTap: () => controller.move(object, level ?? 0, slot),
                ),
                if (slot != LevelSlot.values.last) const SizedBox(width: Insets.xs),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () {
                  unawaited(ref.read(feedbackProvider).objectRemoved());
                  controller.remove(object.id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.unstable,
                    borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trash2, size: 14, color: palette.surface),
                      const SizedBox(width: 5),
                      Text(
                        'Remove',
                        style: AppTypography.caption.copyWith(
                          color: palette.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Slot chip
// ────────────────────────────────────────────────────────────────────────────

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.surfaceSunken,
          borderRadius: const BorderRadius.all(Radius.circular(Corners.pill)),
          border: Border.all(color: selected ? palette.accent : palette.hairline),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: selected ? palette.accentInk : palette.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Space-fill bar — новая механика
//
// Показывает, сколько ширины занято на каждой полке. Синие сегменты = занято,
// серые = свободно. Жёлтый если >90 %. Тап ведёт на Analysis.
// ────────────────────────────────────────────────────────────────────────────

class _SpaceFillBar extends ConsumerWidget {
  const _SpaceFillBar({required this.structureId, required this.units});

  final String structureId;
  final MeasurementSystem units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final AppPalette palette = context.palette;
    final double total = state.structure.widthCm;
    if (total <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/plans/$structureId/analysis'),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Text(
              'SHELF SPACE',
              style: AppTypography.overline.copyWith(
                fontSize: 9,
                color: palette.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (int i = 0; i < state.structure.levels.length; i++) ...[
                    Expanded(
                      child: _FillSegment(
                        level: i,
                        fill: _fillOf(state, i, total),
                        palette: palette,
                      ),
                    ),
                    if (i < state.structure.levels.length - 1)
                      const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              '${units.lengthValue(total)} wide',
              style: AppTypography.overline.copyWith(
                fontSize: 9,
                color: palette.textTertiary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _fillOf(BuilderState state, int levelIndex, double total) {
    final double used = state.structure.levels[levelIndex].objects.fold<double>(
      0,
      (sum, o) => sum + o.widthCm,
    );
    return (used / total).clamp(0.0, 1.0);
  }
}

class _FillSegment extends StatelessWidget {
  const _FillSegment({required this.level, required this.fill, required this.palette});

  final int level;
  final double fill;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color filled = fill > 0.9 ? palette.caution : palette.accent;

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: palette.surfaceSunken),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fill,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(color: filled.withValues(alpha: 0.70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Bottom action dock
// ────────────────────────────────────────────────────────────────────────────

class _ActionDock extends ConsumerWidget {
  const _ActionDock({required this.structureId});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final AppPalette palette = context.palette;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Insets.page, 0, Insets.page, Insets.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.all(Radius.circular(Corners.xxl)),
          border: Border.all(color: palette.hairline),
          boxShadow: Elevations.lifted(palette),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Row(
            children: [
              Expanded(
                child: _DockButton(
                  icon: LucideIcons.plus,
                  label: 'Add',
                  primary: true,
                  onTap: () async {
                    unawaited(ref.read(feedbackProvider).tap());
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ObjectPickerSheet(structureId: structureId),
                    );
                  },
                ),
              ),
              Expanded(
                child: _DockButton(
                  icon: LucideIcons.scale,
                  label: 'Analysis',
                  onTap: () => context.push('/plans/$structureId/analysis'),
                ),
              ),
              Expanded(
                child: _DockButton(
                  icon: LucideIcons.wand,
                  label: 'Suggestions',
                  badge: state.hasSuggestions,
                  onTap: () => context.push('/plans/$structureId/rearrange'),
                ),
              ),
              Expanded(
                child: _DockButton(
                  icon: LucideIcons.rows3,
                  label: 'Levels',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => LevelSettingsSheet(structureId: structureId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(Corners.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary ? palette.accent : palette.surfaceSunken,
                    borderRadius: const BorderRadius.all(Radius.circular(Corners.sm)),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: primary ? palette.accentInk : palette.textPrimary,
                  ),
                ),
                if (badge)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: palette.caution,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: AppTypography.overline.copyWith(
                fontSize: 10,
                letterSpacing: 0.2,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
