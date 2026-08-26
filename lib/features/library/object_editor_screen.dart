import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/utils/ids.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/app_chip.dart';
import 'package:cluckfall_heights/core/widgets/favorite_badge.dart';
import 'package:cluckfall_heights/core/widgets/page_furniture.dart';
import 'package:cluckfall_heights/core/widgets/shelf_card.dart';
import 'package:cluckfall_heights/domain/insights/shelf_favorites.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Creates or edits an object profile.
///
/// A bundled object cannot be overwritten, so opening one offers a copy instead.
/// That keeps the shipped library trustworthy while letting the user keep their own
/// corrected version of anything in it.
class ObjectEditorScreen extends ConsumerStatefulWidget {
  const ObjectEditorScreen({this.objectId, super.key});

  final String? objectId;

  @override
  ConsumerState<ObjectEditorScreen> createState() => _ObjectEditorScreenState();
}

class _ObjectEditorScreenState extends ConsumerState<ObjectEditorScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _width = TextEditingController();
  final TextEditingController _depth = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  Fragility _fragility = Fragility.sturdy;
  ObjectMaterial _material = ObjectMaterial.mixed;
  ObjectCategory _category = ObjectCategory.household;
  StorageObject? _source;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (widget.objectId == null) {
      final MeasurementSystem units = ref.read(preferencesProvider).units;
      _width.text = units.lengthValue(30);
      _depth.text = units.lengthValue(20);
      _height.text = units.lengthValue(20);
      _weight.text = units.weightValue(2);
      setState(() {});
      return;
    }

    final StorageObject? object = ref
        .read(objectProfileRepositoryProvider)
        .byId(widget.objectId!);
    if (object == null) return;

    final MeasurementSystem units = ref.read(preferencesProvider).units;
    _source = object;
    _name.text = object.builtIn ? '${object.name} (my version)' : object.name;
    _width.text = units.lengthValue(object.widthCm, decimals: 1);
    _depth.text = units.lengthValue(object.depthCm, decimals: 1);
    _height.text = units.lengthValue(object.heightCm, decimals: 1);
    _weight.text = units.weightValue(object.weightKg, decimals: 2);
    _fragility = object.fragility;
    _material = object.material;
    _category = object.category;
    setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _depth.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    final double? value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }

  Future<void> _save() async {
    final MeasurementSystem units = ref.read(preferencesProvider).units;
    final double? width = _parse(_width);
    final double? depth = _parse(_depth);
    final double? height = _parse(_height);
    final double? weight = _parse(_weight);

    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the object a name so you can find it later.');
      await ref.read(feedbackProvider).error();
      return;
    }
    if (width == null || depth == null || height == null || weight == null) {
      setState(
        () => _error = 'Every measurement needs to be a number greater than zero.',
      );
      await ref.read(feedbackProvider).error();
      return;
    }

    final bool duplicating = _source?.builtIn ?? false;
    final StorageObject object = StorageObject(
      id: duplicating || _source == null ? newId() : _source!.id,
      name: _name.text.trim(),
      widthCm: units.lengthToCm(width),
      depthCm: units.lengthToCm(depth),
      heightCm: units.lengthToCm(height),
      weightKg: units.weightToKg(weight),
      fragility: _fragility,
      material: _material,
      category: _category,
      artAsset: duplicating ? _source!.artAsset : _source?.artAsset,
    );

    await ref.read(objectLibraryProvider.notifier).save(object);
    await ref.read(feedbackProvider).saved();
    if (!mounted) return;
    context.pop();
  }

  Future<void> _delete() async {
    if (_source == null || _source!.builtIn) return;
    await ref.read(objectLibraryProvider.notifier).delete(_source!.id);
    await ref.read(feedbackProvider).objectRemoved();
    if (!mounted) return;
    context.pop();
  }

  /// A row naming how many shelves carry this profile, plus the badge earned
  /// so far. Empty for a profile that has never been placed: there is nothing
  /// to report yet, and an explicit "0 times" reads as a complaint rather
  /// than information.
  List<Widget> _usageSummary(BuildContext context, String objectId) {
    final int placements = ref.watch(objectPlacementCountsProvider)[objectId] ?? 0;
    if (placements == 0) return const [];

    final AppPalette palette = context.palette;
    final ShelfFavoriteTier tier = ShelfFavorites.tierFor(placements);
    final String placedText = placements == 1 ? 'Placed once so far.' : 'Placed $placements times so far.';

    return [
      ShelfCard(
        accent: tier.earned ? palette.accent : palette.hairline,
        showTrim: false,
        padding: const EdgeInsets.all(Insets.md + 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.earned ? tier.label : 'Not a shelf favourite yet',
                    style: AppTypography.title.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    placedText,
                    style: AppTypography.caption.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            if (tier.earned) FavoriteBadge(tier: tier),
          ],
        ),
      ),
      const SizedBox(height: Insets.xl),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final MeasurementSystem units = ref.watch(preferencesProvider).units;
    final bool builtIn = _source?.builtIn ?? false;

    return AppPage(
      title: _source == null ? 'New object' : (builtIn ? 'Copy object' : 'Edit object'),
      subtitle: builtIn
          ? 'Bundled objects stay as they are. This saves your own copy.'
          : 'Dimensions and weight are what the analysis works from.',
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_source?.artAsset != null)
              Center(child: Image.asset(_source!.artAsset!, height: 110)),
            if (_source?.artAsset != null) const SizedBox(height: Insets.xl),

            if (_source != null) ..._usageSummary(context, _source!.id),

            const SectionLabel('Name'),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Winter blanket box'),
            ),
            const SizedBox(height: Insets.xl),

            SectionLabel('Size in ${units.lengthUnit}'),
            Row(
              children: [
                Expanded(child: _NumberField(label: 'Width', controller: _width)),
                const SizedBox(width: Insets.md),
                Expanded(child: _NumberField(label: 'Depth', controller: _depth)),
                const SizedBox(width: Insets.md),
                Expanded(child: _NumberField(label: 'Height', controller: _height)),
              ],
            ),
            const SizedBox(height: Insets.xl),

            SectionLabel('Weight in ${units.weightUnit}'),
            _NumberField(label: 'Approximate weight', controller: _weight),
            const SizedBox(height: Insets.xl),

            const SectionLabel('How careful should the app be'),
            for (final Fragility fragility in Fragility.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: ShelfCard(
                  accent: fragility == _fragility ? palette.accent : palette.hairline,
                  showTrim: fragility == _fragility,
                  padding: const EdgeInsets.all(Insets.md + 2),
                  onTap: () => setState(() => _fragility = fragility),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fragility.label,
                              style: AppTypography.title.copyWith(color: palette.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fragility.description,
                              style: AppTypography.caption.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (fragility == _fragility)
                        Icon(LucideIcons.check, size: 19, color: palette.accent),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Insets.lg),

            const SectionLabel('Material'),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final ObjectMaterial material in ObjectMaterial.values)
                  AppChip(
                    label: material.label,
                    selected: material == _material,
                    onSelected: () => setState(() => _material = material),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xl),

            const SectionLabel('Where to file it'),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final ObjectCategory category in ObjectCategory.values)
                  AppChip(
                    label: category.label,
                    selected: category == _category,
                    onSelected: () => setState(() => _category = category),
                  ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: Insets.xl),
              ShelfCard(
                accent: palette.unstable,
                showTrim: false,
                padding: const EdgeInsets.all(Insets.md + 2),
                child: Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 18, color: palette.unstable),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTypography.caption.copyWith(color: palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Insets.xxl),
            AppButton(
              label: builtIn ? 'Save my copy' : 'Save object',
              onPressed: _save,
            ),
            if (_source != null && !builtIn) ...[
              const SizedBox(height: Insets.md),
              AppButton(
                label: 'Delete object',
                kind: AppButtonKind.destructive,
                onPressed: _delete,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                'Plans that already use it keep their own copy of these numbers.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label, hintText: '0'),
    );
  }
}
