import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:cluckfall_heights/features/builder/builder_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Edits the frame: its name, its size, and each level's capacity.
///
/// Capacity is editable per level because the app cannot know what the user's
/// actual shelf is rated for. The default is an assumption, and every overload
/// warning says so and points here.
class LevelSettingsSheet extends ConsumerWidget {
  const LevelSettingsSheet({required this.structureId, super.key});

  final String structureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BuilderState state = ref.watch(builderProvider(structureId));
    final BuilderController controller = ref.read(builderProvider(structureId).notifier);
    final MeasurementSystem units = ref.watch(preferencesProvider).units;
    final AppPalette palette = context.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, Insets.xxl),
        children: [
          Text(
            'Plan settings',
            style: AppTypography.heading.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: Insets.xl),

          const SectionLabel('Name'),
          TextFormField(
            initialValue: state.structure.name,
            textCapitalization: TextCapitalization.sentences,
            onFieldSubmitted: controller.rename,
            decoration: const InputDecoration(
              hintText: 'Plan name',
              helperText: 'Press return to rename',
            ),
          ),
          const SizedBox(height: Insets.xl),

          const SectionLabel('Frame'),
          _Slider(
            label: 'Width',
            value: state.structure.widthCm,
            min: 20,
            max: 240,
            units: units,
            onChanged: (v) => controller.resize(widthCm: v),
          ),
          _Slider(
            label: 'Height',
            value: state.structure.heightCm,
            min: 20,
            max: 260,
            units: units,
            onChanged: (v) => controller.resize(heightCm: v),
          ),
          _Slider(
            label: 'Depth',
            value: state.structure.depthCm,
            min: 10,
            max: 120,
            units: units,
            onChanged: (v) => controller.resize(depthCm: v),
          ),
          const SizedBox(height: Insets.lg),

          SectionLabel('Levels  (${state.structure.levels.length} of 10)'),
          for (int i = state.structure.levels.length - 1; i >= 0; i--)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _LevelCard(
                index: i,
                level: state.structure.levels[i],
                load: state.report.levelLoads.length > i
                    ? state.report.levelLoads[i]
                    : null,
                units: units,
                canRemove: state.structure.levels.length > 1,
                onCapacityChanged: (v) => controller.setLevelCapacity(i, v),
                onRemove: () {
                  ref.read(feedbackProvider).tap();
                  controller.removeLevel(i);
                },
              ),
            ),
          if (state.structure.levels.length < 10)
            AppButton(
              label: 'Add a level',
              icon: LucideIcons.plus,
              kind: AppButtonKind.secondary,
              onPressed: () {
                ref.read(feedbackProvider).tap();
                controller.addLevel();
              },
            ),

          const SizedBox(height: Insets.xxl),
          AppButton(
            label: 'Delete this plan',
            kind: AppButtonKind.destructive,
            onPressed: () async {
              await ref.read(structuresProvider.notifier).delete(structureId);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              context.go('/plans');
            },
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.index,
    required this.level,
    required this.load,
    required this.units,
    required this.canRemove,
    required this.onCapacityChanged,
    required this.onRemove,
  });

  final int index;
  final StorageLevel level;
  final LevelLoad? load;
  final MeasurementSystem units;
  final bool canRemove;
  final ValueChanged<double> onCapacityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool overloaded = load?.isOverloaded ?? false;

    return ShelfCard(
      accent: overloaded ? palette.unstable : palette.hairline,
      showTrim: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${index + 1}',
                      style: AppTypography.title.copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${level.objects.length} '
                      '${level.objects.length == 1 ? 'item' : 'items'} · '
                      '${units.weight(level.loadKg)} of '
                      '${units.weight(level.capacityKg)} · '
                      '${units.length(level.clearanceCm)} clearance',
                      style: AppTypography.caption.copyWith(
                        color: overloaded ? palette.unstable : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (canRemove)
                CircleAction(
                  icon: LucideIcons.minus,
                  tooltip: 'Remove level ${index + 1}',
                  onTap: onRemove,
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: [
              Text(
                'Capacity',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: level.capacityKg.clamp(2, 120),
                  min: 2,
                  max: 120,
                  divisions: 59,
                  onChanged: onCapacityChanged,
                ),
              ),
              Text(
                units.weight(level.capacityKg, decimals: 0),
                style: AppTypography.numeric.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.units,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final MeasurementSystem units;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            units.length(value),
            textAlign: TextAlign.right,
            style: AppTypography.numeric.copyWith(color: palette.textPrimary),
          ),
        ),
      ],
    );
  }
}
