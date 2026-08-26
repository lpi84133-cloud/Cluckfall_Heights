import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/theme/material_tint.dart';
import 'package:cluckfall_heights/core/widgets/status_badge.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/analysis/stability_status.dart';
import 'package:cluckfall_heights/domain/objects/object_traits.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _DragPayload {
  const _DragPayload(this.object, this.levelIndex);

  final PlacedObject object;
  final int levelIndex;
}

/// The core visual plan.
///
/// Objects are drawn at their real proportions:
///   width  = objectWidthCm / structureWidthCm
///   height = objectHeightCm / levelClearanceCm  (clamped to avoid overflow)
///
/// This makes a 42 cm toolbox in a 90 cm shelf occupy ~47% of the shelf width,
/// while a 9 cm bottle occupies ~10%. The drawing is now a fair miniature of
/// what the real shelf looks like, not a grid of equal boxes.
///
/// Each empty level has a centred "+" tap zone that opens the picker directly,
/// without going through the bottom dock. Tapping a placed object selects it;
/// the builder_screen shows a bottom panel with a visible trash button.
class StructureCanvas extends StatelessWidget {
  const StructureCanvas({
    required this.structure,
    required this.report,
    this.selectedObjectId,
    this.onSelectObject,
    this.onMoveObject,
    this.onTapSlot,
    this.onTapEmptyLevel,
    this.showCentreOfMass = true,
    this.interactive = true,
    super.key,
  });

  final Structure structure;
  final StabilityReport report;
  final String? selectedObjectId;
  final ValueChanged<PlacedObject?>? onSelectObject;
  final void Function(PlacedObject object, int levelIndex, LevelSlot slot)? onMoveObject;
  final void Function(int levelIndex, LevelSlot slot)? onTapSlot;

  /// Called when the user taps the "+" on an empty level — opens the picker at
  /// that level without going through the dock Add button.
  final ValueChanged<int>? onTapEmptyLevel;

  final bool showCentreOfMass;
  final bool interactive;

  static const double _railW = 11.0;
  static const double _plankH = 14.0;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double totalClearance = structure.levels.fold<double>(
      0,
      (sum, level) => sum + level.clearanceCm,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _canvasBg(palette),
                borderRadius: Corners.card,
                border: Border.all(color: _railColor(palette), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(Corners.lg - 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rail(palette: palette),
                    Expanded(
                      child: Column(
                        verticalDirection: VerticalDirection.up,
                        children: [
                          _Plank(palette: palette, capacityUse: 0, overloaded: false),
                          for (int i = 0; i < structure.levels.length; i++)
                            Expanded(
                              flex: _flex(structure.levels[i].clearanceCm, totalClearance),
                              child: _LevelRow(
                                structure: structure,
                                report: report,
                                levelIndex: i,
                                selectedObjectId: selectedObjectId,
                                onSelectObject: onSelectObject,
                                onMoveObject: onMoveObject,
                                onTapSlot: onTapSlot,
                                onTapEmptyLevel: onTapEmptyLevel,
                                interactive: interactive,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _Rail(palette: palette),
                  ],
                ),
              ),
            ),
            if (showCentreOfMass && !report.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: _CentreOfMassMarker(report: report),
                ),
              ),
          ],
        );
      },
    );
  }

  static int _flex(double clearanceCm, double total) {
    if (total <= 0) return 1000;
    return ((clearanceCm / total) * 1000).round().clamp(1, 1000);
  }

  static Color _canvasBg(AppPalette palette) =>
      Color.lerp(palette.surfaceSunken, const Color(0xFF1B1510), 0.55)!;

  static Color _railColor(AppPalette palette) =>
      Color.lerp(palette.shelfEdge, palette.hairline, 0.45)!;
}

// ────────────────────────────────────────────────────────────────────────────
// Side upright
// ────────────────────────────────────────────────────────────────────────────

class _Rail extends StatelessWidget {
  const _Rail({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final Color base = Color.lerp(palette.shelfEdge, const Color(0xFFA07040), 0.6)!;
    return Container(
      width: StructureCanvas._railW,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base.withValues(alpha: 0.95),
            base.withValues(alpha: 0.60),
            base.withValues(alpha: 0.85),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shelf plank
// ────────────────────────────────────────────────────────────────────────────

class _Plank extends StatelessWidget {
  const _Plank({
    required this.palette,
    required this.capacityUse,
    required this.overloaded,
    this.flagged = false,
    this.flagColor,
    this.levelNumber,
    this.widthFill = 0,
  });

  final AppPalette palette;
  final double capacityUse;
  final bool overloaded;
  final bool flagged;
  final Color? flagColor;
  final int? levelNumber;

  /// Fraction of the shelf width actually occupied by objects (0-1).
  final double widthFill;

  @override
  Widget build(BuildContext context) {
    final Color wood = Color.lerp(palette.shelfEdge, const Color(0xFF9C6B35), 0.5)!;
    final Color loadColor = overloaded
        ? palette.unstable
        : flagged
        ? flagColor ?? palette.caution
        : palette.shelfEdge;

    return SizedBox(
      height: StructureCanvas._plankH,
      child: Stack(
        children: [
          // Wood grain body
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(wood, Colors.white, 0.22)!,
                    wood,
                    Color.lerp(wood, Colors.black, 0.25)!,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          // Weight load bar (bottom edge)
          if (capacityUse > 0)
            Positioned(
              left: 0,
              bottom: 0,
              width: double.infinity,
              height: 3,
              child: FractionallySizedBox(
                widthFactor: capacityUse.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: loadColor.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          // Width fill indicator (top edge) — new mechanic
          if (widthFill > 0)
            Positioned(
              left: 0,
              top: 0,
              width: double.infinity,
              height: 2,
              child: FractionallySizedBox(
                widthFactor: widthFill.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widthFill > 0.9
                        ? palette.caution.withValues(alpha: 0.75)
                        : palette.accent.withValues(alpha: 0.50),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          // Level number
          if (levelNumber != null)
            Positioned(
              right: 5,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  '$levelNumber',
                  style: AppTypography.overline.copyWith(
                    fontSize: 9,
                    color: Color.lerp(wood, Colors.black, 0.65)!,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Level row
// ────────────────────────────────────────────────────────────────────────────

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.structure,
    required this.report,
    required this.levelIndex,
    required this.selectedObjectId,
    required this.onSelectObject,
    required this.onMoveObject,
    required this.onTapSlot,
    required this.onTapEmptyLevel,
    required this.interactive,
  });

  final Structure structure;
  final StabilityReport report;
  final int levelIndex;
  final String? selectedObjectId;
  final ValueChanged<PlacedObject?>? onSelectObject;
  final void Function(PlacedObject object, int levelIndex, LevelSlot slot)? onMoveObject;
  final void Function(int levelIndex, LevelSlot slot)? onTapSlot;
  final ValueChanged<int>? onTapEmptyLevel;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final StorageLevel level = structure.levels[levelIndex];
    final LevelLoad load = report.levelLoads.length > levelIndex
        ? report.levelLoads[levelIndex]
        : const LevelLoad(
            levelIndex: 0,
            weightKg: 0,
            share: 0,
            capacityUse: 0,
            capacityKg: 0,
            objectCount: 0,
            fragileCount: 0,
          );

    final bool flagged = report.findingsForLevel(levelIndex).isNotEmpty;
    final StabilityStatus levelStatus = report.findingsForLevel(levelIndex).fold(
      StabilityStatus.stable,
      (worst, f) => worst.worseOf(f.severity),
    );

    // Width fill: sum of object widths / structure width — new mechanic
    final double widthUsed = level.objects.fold<double>(
      0,
      (sum, o) => sum + o.widthCm,
    );
    final double widthFill = structure.widthCm > 0
        ? (widthUsed / structure.widthCm)
        : 0;

    final bool isEmpty = level.objects.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: isEmpty && interactive
              // ── Empty level: one big tap target with a + hint ──────────────
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTapEmptyLevel?.call(levelIndex),
                  child: _EmptyLevelHint(
                    palette: palette,
                    levelIndex: levelIndex,
                  ),
                )
              // ── Filled level: three-slot layout ───────────────────────────
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int s = 0; s < LevelSlot.values.length; s++) ...[
                      Expanded(
                        child: _SlotCell(
                          level: level,
                          levelIndex: levelIndex,
                          slot: LevelSlot.values[s],
                          structureWidthCm: structure.widthCm,
                          selectedObjectId: selectedObjectId,
                          onSelectObject: onSelectObject,
                          onMoveObject: onMoveObject,
                          onTapSlot: onTapSlot,
                          interactive: interactive,
                          palette: palette,
                        ),
                      ),
                      if (s < LevelSlot.values.length - 1)
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: palette.hairline.withValues(alpha: 0.18),
                        ),
                    ],
                  ],
                ),
        ),
        _Plank(
          palette: palette,
          capacityUse: load.capacityUse,
          overloaded: load.isOverloaded,
          flagged: flagged,
          flagColor: levelStatus.ink(palette),
          levelNumber: levelIndex + 1,
          widthFill: widthFill,
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Empty level hint
// ────────────────────────────────────────────────────────────────────────────

class _EmptyLevelHint extends StatelessWidget {
  const _EmptyLevelHint({required this.palette, required this.levelIndex});

  final AppPalette palette;
  final int levelIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dot grid background
        Positioned.fill(
          child: CustomPaint(
            painter: _DotGridPainter(
              color: palette.hairline.withValues(alpha: 0.22),
            ),
          ),
        ),
        // Centred "+" hint
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: palette.accentWash.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(
                color: palette.accent.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.plus,
                  size: 12,
                  color: palette.accent.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 4),
                Text(
                  'Add here',
                  style: AppTypography.overline.copyWith(
                    fontSize: 10,
                    color: palette.accent.withValues(alpha: 0.70),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dot = Paint()..color = color;
    const double step = 14;
    const double r = 1.0;
    for (double x = step / 2; x < size.width; x += step) {
      for (double y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

// ────────────────────────────────────────────────────────────────────────────
// Slot cell (filled levels)
// ────────────────────────────────────────────────────────────────────────────

class _SlotCell extends StatefulWidget {
  const _SlotCell({
    required this.level,
    required this.levelIndex,
    required this.slot,
    required this.structureWidthCm,
    required this.selectedObjectId,
    required this.onSelectObject,
    required this.onMoveObject,
    required this.onTapSlot,
    required this.interactive,
    required this.palette,
  });

  final StorageLevel level;
  final int levelIndex;
  final LevelSlot slot;
  final double structureWidthCm;
  final String? selectedObjectId;
  final ValueChanged<PlacedObject?>? onSelectObject;
  final void Function(PlacedObject object, int levelIndex, LevelSlot slot)? onMoveObject;
  final void Function(int levelIndex, LevelSlot slot)? onTapSlot;
  final bool interactive;
  final AppPalette palette;

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final List<PlacedObject> objects = widget.level.objects
        .where((o) => o.slot == widget.slot)
        .toList(growable: false);

    final Widget content = Container(
      color: _hovering
          ? widget.palette.accentWash.withValues(alpha: 0.18)
          : Colors.transparent,
      child: objects.isEmpty
          ? const SizedBox.expand()
          : LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final PlacedObject object in objects)
                      _ObjectTile(
                        object: object,
                        levelIndex: widget.levelIndex,
                        selected: object.id == widget.selectedObjectId,
                        levelClearanceCm: widget.level.clearanceCm,
                        slotWidthCm: widget.structureWidthCm / LevelSlot.values.length,
                        available: constraints,
                        onTap: widget.interactive
                            ? () => widget.onSelectObject?.call(
                                object.id == widget.selectedObjectId ? null : object,
                              )
                            : null,
                        draggable: widget.interactive && widget.onMoveObject != null,
                      ),
                  ],
                );
              },
            ),
    );

    if (!widget.interactive) return content;

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        final bool same =
            details.data.levelIndex == widget.levelIndex &&
            details.data.object.slot == widget.slot;
        if (!same) setState(() => _hovering = true);
        return !same;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onMoveObject?.call(
          details.data.object,
          widget.levelIndex,
          widget.slot,
        );
      },
      builder: (_, _, _) => GestureDetector(
        onTap: () => widget.onTapSlot?.call(widget.levelIndex, widget.slot),
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Object tile — proportional sizing
// ────────────────────────────────────────────────────────────────────────────

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({
    required this.object,
    required this.levelIndex,
    required this.selected,
    required this.levelClearanceCm,
    required this.slotWidthCm,
    required this.available,
    required this.onTap,
    required this.draggable,
  });

  final PlacedObject object;
  final int levelIndex;
  final bool selected;
  final double levelClearanceCm;
  final double slotWidthCm;
  final BoxConstraints available;
  final VoidCallback? onTap;
  final bool draggable;

  /// Fraction of the slot width this object should occupy.
  double get _widthFraction {
    if (slotWidthCm <= 0) return 0.72;
    // Clamp so tiny objects stay visible (min 22%) and big ones don't overflow (100%)
    return (object.widthCm / slotWidthCm).clamp(0.22, 1.0);
  }

  double get _heightFraction {
    if (levelClearanceCm <= 0) return 0.72;
    return (object.heightCm / levelClearanceCm).clamp(0.40, 0.96);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    final double pixelW = (available.maxWidth * _widthFraction).clamp(28.0, available.maxWidth);
    final Widget art = object.artAsset != null
        ? Image.asset(object.artAsset!, fit: BoxFit.contain)
        : _CustomObjectBlock(object: object);

    // The art itself, with the selection indicator and fragility badge
    // layered inside the same sized box so all overlays track the image
    // position exactly, regardless of _heightFraction.
    final Widget artBox = FractionallySizedBox(
      heightFactor: _heightFraction,
      alignment: Alignment.bottomCenter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: art,
            ),
          ),
          // ── Fragility badge (top-right of the art) ────────────────────
          if (object.fragility == Fragility.fragile)
            Positioned(
              right: 0,
              top: -2,
              child: Image.asset(IndicatorArt.fragileSymbol, width: 13),
            ),
          if (object.fragility == Fragility.delicate)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.caution,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.surface.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
              ),
            ),
          // ── Selection: glowing dot right above the top of the art ─────
          if (selected)
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.surface.withValues(alpha: 0.85),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.60),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final Widget body = SizedBox(
      width: pixelW,
      child: artBox,
    );

    final Widget tappable = Semantics(
      button: onTap != null,
      selected: selected,
      label: '${object.name}, level ${levelIndex + 1}, ${object.slot.label}',
      child: GestureDetector(onTap: onTap, child: body),
    );

    if (!draggable) return tappable;

    return LongPressDraggable<_DragPayload>(
      data: _DragPayload(object, levelIndex),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.92,
          child: SizedBox(
            width: 60,
            height: 60,
            child: art,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.18, child: body),
      child: tappable,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Custom object block (no artwork)
// ────────────────────────────────────────────────────────────────────────────

class _CustomObjectBlock extends StatelessWidget {
  const _CustomObjectBlock({required this.object});

  final PlacedObject object;

  @override
  Widget build(BuildContext context) {
    final Color fill = object.material.tint(context.palette);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(Corners.xs)),
        border: Border.all(color: Colors.black.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              object.name.isEmpty ? '?' : object.name.substring(0, 1).toUpperCase(),
              style: AppTypography.numeric.copyWith(
                color: const Color(0xFF2E2A22),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Centre-of-mass marker
// ────────────────────────────────────────────────────────────────────────────

class _CentreOfMassMarker extends StatelessWidget {
  const _CentreOfMassMarker({required this.report});

  final StabilityReport report;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double x = constraints.maxWidth / 2 *
            (1 + report.centreOfMassX.clamp(-1.0, 1.0));
        final double y = constraints.maxHeight *
            (1 - report.centreOfMassHeight.clamp(0.0, 1.0));

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: y,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: context.palette.textPrimary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                child: const SizedBox(height: 1),
              ),
            ),
            AnimatedPositioned(
              duration: Motion.normal,
              curve: Motion.enter,
              left: x - 17,
              top: y - 17,
              child: Image.asset(IndicatorArt.centerOfMassBadge, width: 34),
            ),
          ],
        );
      },
    );
  }
}
