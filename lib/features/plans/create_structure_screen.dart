import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/utils/ids.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:cluckfall_heights/domain/structures/structure_type.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Create Structure: pick a type, confirm the dimensions, choose how many levels.
///
/// Every field starts from a sensible default for the chosen type, so the user can
/// go straight to the builder and adjust later rather than being asked for six
/// measurements before seeing anything.
class CreateStructureScreen extends ConsumerStatefulWidget {
  const CreateStructureScreen({super.key});

  @override
  ConsumerState<CreateStructureScreen> createState() => _CreateStructureScreenState();
}

class _CreateStructureScreenState extends ConsumerState<CreateStructureScreen> {
  final TextEditingController _name = TextEditingController();
  StructureType _type = StructureType.shelf;
  late double _width;
  late double _depth;
  late double _height;
  late int _levels;

  @override
  void initState() {
    super.initState();
    _applyDefaults(StructureType.shelf);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _applyDefaults(StructureType type) {
    final ({double width, double depth, double height, int levels}) preset = type.defaults;
    _type = type;
    _width = preset.width;
    _depth = preset.depth;
    _height = preset.height;
    _levels = preset.levels;
  }

  Future<void> _create() async {
    final MeasurementSystem units = ref.read(preferencesProvider).units;
    final String name = _name.text.trim().isEmpty
        ? '${_type.label} ${units.length(_width)}'
        : _name.text.trim();

    final Structure structure = Structure.blank(
      id: newId(),
      name: name,
      type: _type,
      levelIds: [for (int i = 0; i < _levels; i++) newId()],
      now: DateTime.now(),
      widthCm: _width,
      depthCm: _depth,
      heightCm: _height,
    );

    await ref.read(structuresProvider.notifier).save(structure);
    await ref.read(feedbackProvider).saved();
    if (!mounted) return;
    // pushReplacement keeps PlansScreen in the stack so back works from BuilderScreen.
    context.pushReplacement('/plans/${structure.id}');
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final MeasurementSystem units = ref.watch(preferencesProvider).units;

    return AppPage(
      title: 'New plan',
      subtitle: 'Start from a type, then fine-tune the measurements.',
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('What are you planning'),
            for (final StructureType type in StructureType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: ShelfCard(
                  accent: type == _type ? palette.accent : palette.hairline,
                  showTrim: type == _type,
                  onTap: () {
                    ref.read(feedbackProvider).tap();
                    setState(() => _applyDefaults(type));
                  },
                  padding: const EdgeInsets.all(Insets.md + 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.label,
                              style: AppTypography.title.copyWith(color: palette.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type.description,
                              style: AppTypography.caption.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (type == _type)
                        Icon(LucideIcons.check, size: 19, color: palette.accent),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: '${_type.label} in the hallway'),
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Measurements'),
            _Measure(
              label: 'Width',
              value: _width,
              min: 20,
              max: 240,
              units: units,
              onChanged: (v) => setState(() => _width = v),
            ),
            _Measure(
              label: 'Depth',
              value: _depth,
              min: 10,
              max: 120,
              units: units,
              onChanged: (v) => setState(() => _depth = v),
            ),
            _Measure(
              label: 'Height',
              value: _height,
              min: 20,
              max: 260,
              units: units,
              onChanged: (v) => setState(() => _height = v),
            ),
            const SizedBox(height: Insets.lg),

            const SectionLabel('Levels'),
            ShelfCard(
              showTrim: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_levels ${_levels == 1 ? 'level' : 'levels'}',
                          style: AppTypography.title.copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${units.length(_height / _levels)} of clearance each, and '
                          '${units.weight(Structure.defaultCapacityFor(_type, _width))} '
                          'assumed per level.',
                          style: AppTypography.caption.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _Stepper(
                    value: _levels,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => _levels = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xxl),

            AppButton(label: 'Create and start placing', onPressed: _create),
            const SizedBox(height: Insets.md),
            Text(
              'Nothing is final: every measurement stays editable from inside the plan.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: palette.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Measure extends StatelessWidget {
  const _Measure({
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

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
                ),
              ),
              Text(
                units.length(value),
                style: AppTypography.numeric.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    Widget button(IconData icon, String tooltip, int next, bool enabled) {
      return Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: enabled ? () => onChanged(next) : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled ? palette.surfaceSunken : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(
              icon,
              size: 17,
              color: enabled ? palette.textPrimary : palette.textTertiary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(LucideIcons.minus, 'Remove a level', value - 1, value > min),
        const SizedBox(width: Insets.sm),
        button(LucideIcons.plus, 'Add a level', value + 1, value < max),
      ],
    );
  }
}
