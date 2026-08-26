import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/utils/ids.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement.dart';
import 'package:cluckfall_heights/domain/analysis/rearrangement_planner.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/analysis/stability_report.dart';
import 'package:cluckfall_heights/domain/objects/placed_object.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/structures/level_slot.dart';
import 'package:cluckfall_heights/domain/structures/storage_level.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class BuilderState {
  const BuilderState({
    required this.structure,
    required this.report,
    this.selectedObjectId,
    this.focusedLevelIndex = 0,
    this.focusedSlot = LevelSlot.centre,
    this.canUndo = false,
  });

  final Structure structure;
  final StabilityReport report;
  final String? selectedObjectId;

  /// Where a newly picked object will land, so choosing from the library does
  /// not need a second "where?" step.
  final int focusedLevelIndex;
  final LevelSlot focusedSlot;

  final bool canUndo;

  PlacedObject? get selectedObject => selectedObjectId == null
      ? null
      : structure.allObjects.where((o) => o.id == selectedObjectId).firstOrNull;

  bool get hasSuggestions => RearrangementPlanner.shouldSuggest(report);
}

/// Holds the structure being edited.
///
/// Changes are written straight through to the local box: there is no server and
/// nothing to lose by saving, so the app never asks the user to remember to save.
/// An undo stack covers the case a save button is usually there to protect
/// against, which is a change made by accident.
class BuilderController extends FamilyNotifier<BuilderState, String> {
  final List<Structure> _history = [];

  @override
  BuilderState build(String structureId) {
    final Structure? structure = ref.watch(structureRepositoryProvider).byId(structureId);
    if (structure == null) {
      throw StateError('Plan $structureId is not on this device');
    }
    return BuilderState(structure: structure, report: StabilityAnalyzer.analyse(structure));
  }

  void _commit(Structure next, {bool recordHistory = true}) {
    if (recordHistory) {
      _history.add(state.structure);
      if (_history.length > 30) _history.removeAt(0);
    }
    final Structure stamped = next.copyWith(updatedAt: DateTime.now());
    state = BuilderState(
      structure: stamped,
      report: StabilityAnalyzer.analyse(stamped),
      selectedObjectId: state.selectedObjectId,
      focusedLevelIndex: state.focusedLevelIndex.clamp(0, stamped.levels.length - 1),
      focusedSlot: state.focusedSlot,
      canUndo: _history.isNotEmpty,
    );
    ref.read(structureRepositoryProvider).save(stamped);
  }

  void select(PlacedObject? object) {
    state = BuilderState(
      structure: state.structure,
      report: state.report,
      selectedObjectId: object?.id,
      focusedLevelIndex: object == null
          ? state.focusedLevelIndex
          : state.structure.levelIndexOfObject(object.id) ?? state.focusedLevelIndex,
      focusedSlot: object?.slot ?? state.focusedSlot,
      canUndo: state.canUndo,
    );
  }

  void focus(int levelIndex, LevelSlot slot) {
    state = BuilderState(
      structure: state.structure,
      report: state.report,
      selectedObjectId: null,
      focusedLevelIndex: levelIndex,
      focusedSlot: slot,
      canUndo: state.canUndo,
    );
  }

  void place(StorageObject object) {
    final PlacedObject placed = PlacedObject.fromObject(
      object,
      id: newId(),
      slot: state.focusedSlot,
    );
    final List<StorageLevel> levels = [...state.structure.levels];
    levels[state.focusedLevelIndex] = levels[state.focusedLevelIndex].withObjectAdded(placed);
    _commit(state.structure.copyWith(levels: levels));
  }

  void move(PlacedObject object, int levelIndex, LevelSlot slot) {
    Structure next = state.structure;
    if (next.levelIndexOfObject(object.id) != levelIndex) {
      next = next.withObjectMoved(object.id, levelIndex);
    }
    _commit(next.withObjectSlotChanged(object.id, slot));
  }

  void remove(String objectId) {
    final int? index = state.structure.levelIndexOfObject(objectId);
    if (index == null) return;
    final List<StorageLevel> levels = [...state.structure.levels];
    levels[index] = levels[index].withObjectRemoved(objectId);
    _commit(state.structure.copyWith(levels: levels));
    select(null);
  }

  void changeWeight(String objectId, double weightKg) {
    final int? index = state.structure.levelIndexOfObject(objectId);
    if (index == null) return;
    final List<StorageLevel> levels = [...state.structure.levels];
    levels[index] = levels[index].copyWith(
      objects: levels[index].objects
          .map((o) => o.id == objectId ? o.copyWith(weightKg: weightKg) : o)
          .toList(growable: false),
    );
    _commit(state.structure.copyWith(levels: levels));
  }

  void addLevel() {
    if (state.structure.levels.length >= 10) return;
    final Structure structure = state.structure;
    final int count = structure.levels.length + 1;
    final double clearance = structure.heightCm / count;

    _commit(
      structure.copyWith(
        levels: [
          for (final StorageLevel level in structure.levels)
            level.copyWith(clearanceCm: clearance),
          StorageLevel(
            id: newId(),
            clearanceCm: clearance,
            capacityKg: Structure.defaultCapacityFor(structure.type, structure.widthCm),
          ),
        ],
      ),
    );
  }

  /// Removing a level moves anything on it down rather than deleting the user's
  /// objects, which is never what they meant by "remove a shelf".
  void removeLevel(int levelIndex) {
    final Structure structure = state.structure;
    if (structure.levels.length <= 1) return;

    final List<PlacedObject> displaced = structure.levels[levelIndex].objects;
    final List<StorageLevel> levels = [...structure.levels]..removeAt(levelIndex);
    final int target = levelIndex == 0 ? 0 : levelIndex - 1;
    if (displaced.isNotEmpty) {
      levels[target] = levels[target].copyWith(objects: [...levels[target].objects, ...displaced]);
    }

    final double clearance = structure.heightCm / levels.length;
    _commit(
      structure.copyWith(
        levels: [
          for (final StorageLevel level in levels) level.copyWith(clearanceCm: clearance),
        ],
      ),
    );
  }

  void setLevelCapacity(int levelIndex, double capacityKg) {
    final List<StorageLevel> levels = [...state.structure.levels];
    levels[levelIndex] = levels[levelIndex].copyWith(capacityKg: capacityKg);
    _commit(state.structure.copyWith(levels: levels));
  }

  void rename(String name) {
    if (name.trim().isEmpty) return;
    _commit(state.structure.copyWith(name: name.trim()));
  }

  void resize({double? widthCm, double? heightCm, double? depthCm}) {
    final Structure structure = state.structure;
    final double height = heightCm ?? structure.heightCm;
    final double clearance = height / structure.levels.length;
    _commit(
      structure.copyWith(
        widthCm: widthCm,
        depthCm: depthCm,
        heightCm: height,
        levels: [
          for (final StorageLevel level in structure.levels)
            level.copyWith(clearanceCm: clearance),
        ],
      ),
    );
  }

  void applySuggestion(Rearrangement suggestion) =>
      _commit(RearrangementPlanner.apply(state.structure, suggestion));

  void undo() {
    if (_history.isEmpty) return;
    final Structure previous = _history.removeLast();
    _commit(previous, recordHistory: false);
  }
}

final NotifierProviderFamily<BuilderController, BuilderState, String> builderProvider =
    NotifierProvider.family<BuilderController, BuilderState, String>(BuilderController.new);
