import 'dart:async';

import 'package:cluckfall_heights/data/local/local_store.dart';
import 'package:cluckfall_heights/data/repositories/backup_service.dart';
import 'package:cluckfall_heights/data/repositories/object_profile_repository.dart';
import 'package:cluckfall_heights/data/repositories/preferences_repository.dart';
import 'package:cluckfall_heights/data/repositories/structure_repository.dart';
import 'package:cluckfall_heights/domain/insights/portfolio_insights.dart';
import 'package:cluckfall_heights/domain/insights/shelf_favorites.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:cluckfall_heights/domain/units/measurement_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the on-device boxes.
///
/// The startup sequence awaits this as its first task, and the router will not
/// show any other screen until startup has finished, which is why the
/// repositories below can safely read it as a resolved value.
final FutureProvider<LocalStore> localStoreProvider = FutureProvider<LocalStore>(
  (ref) => LocalStore.open(),
);

final Provider<StructureRepository> structureRepositoryProvider = Provider<StructureRepository>(
  (ref) => StructureRepository(ref.watch(localStoreProvider).requireValue),
);

final Provider<ObjectProfileRepository> objectProfileRepositoryProvider =
    Provider<ObjectProfileRepository>(
      (ref) => ObjectProfileRepository(ref.watch(localStoreProvider).requireValue),
    );

final Provider<PreferencesRepository> preferencesRepositoryProvider =
    Provider<PreferencesRepository>(
      (ref) => PreferencesRepository(ref.watch(localStoreProvider).requireValue),
    );

final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    structures: ref.watch(structureRepositoryProvider),
    objects: ref.watch(objectProfileRepositoryProvider),
    preferences: ref.watch(preferencesRepositoryProvider),
  ),
);

/// User settings, kept in memory and written through on every change.
class PreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.watch(preferencesRepositoryProvider).read();

  Future<void> _update(AppPreferences next) async {
    state = next;
    await ref.read(preferencesRepositoryProvider).write(next);
  }

  Future<void> update(AppPreferences Function(AppPreferences current) change) =>
      _update(change(state));

  Future<void> setUnits(MeasurementSystem units) =>
      _update(state.copyWith(units: units));

  Future<void> setTheme(AppThemeChoice theme) => _update(state.copyWith(theme: theme));

  Future<void> setSoundEnabled(bool enabled) =>
      _update(state.copyWith(soundEnabled: enabled));

  Future<void> setHapticsEnabled(bool enabled) =>
      _update(state.copyWith(hapticsEnabled: enabled));

  Future<void> setDisplayName(String name) =>
      _update(state.copyWith(displayName: name.trim()));

  Future<void> setAvatarPath(String? path) => _update(
    path == null
        ? state.copyWith(clearAvatar: true)
        : state.copyWith(avatarPath: path),
  );

  Future<void> completeOnboarding() {
    if (state.onboardingCompleted) return Future<void>.value();
    return _update(state.copyWith(onboardingCompleted: true));
  }
}

final NotifierProvider<PreferencesNotifier, AppPreferences> preferencesProvider =
    NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);

/// Split out so the root widget rebuilds on a theme change alone, rather than on
/// every unrelated preference write.
///
/// Until the boxes are open there is no stored preference to read, and the root
/// widget is built before that happens. Following the system for those first
/// frames is both correct and the least jarring: on a device set to dark, the
/// loading screen does not flash light and then correct itself.
final Provider<ThemeMode> themeModeProvider = Provider<ThemeMode>((ref) {
  if (!ref.watch(localStoreProvider).hasValue) return ThemeMode.system;

  return switch (ref.watch(preferencesProvider.select((p) => p.theme))) {
    AppThemeChoice.system => ThemeMode.system,
    AppThemeChoice.light => ThemeMode.light,
    AppThemeChoice.dark => ThemeMode.dark,
  };
});

/// Saved structures, newest first, kept in step with the box.
class StructuresNotifier extends Notifier<List<Structure>> {
  @override
  List<Structure> build() {
    final StructureRepository repository = ref.watch(structureRepositoryProvider);
    final StreamSubscription<void> subscription = repository.changes().listen((_) {
      state = repository.all();
    });
    ref.onDispose(subscription.cancel);
    return repository.all();
  }

  Future<void> save(Structure structure) =>
      ref.read(structureRepositoryProvider).save(structure);

  Future<void> delete(String id) => ref.read(structureRepositoryProvider).delete(id);
}

final NotifierProvider<StructuresNotifier, List<Structure>> structuresProvider =
    NotifierProvider<StructuresNotifier, List<Structure>>(StructuresNotifier.new);

/// Everything planned so far, read as one picture.
///
/// Derived from [structuresProvider] so it recomputes whenever a plan changes,
/// and nowhere else needs to know how the aggregation works.
final Provider<PortfolioInsights> insightsProvider = Provider<PortfolioInsights>(
  (ref) => PortfolioInsights.from(ref.watch(structuresProvider)),
);

/// How many times each library profile has actually been placed, keyed by its
/// id. Feeds the shelf-favourite badge on the library and picker cards.
final Provider<Map<String, int>> objectPlacementCountsProvider = Provider<Map<String, int>>(
  (ref) => ShelfFavorites.placementCounts(ref.watch(structuresProvider)),
);

/// The object library: user profiles followed by the bundled definitions.
class ObjectLibraryNotifier extends Notifier<List<StorageObject>> {
  @override
  List<StorageObject> build() {
    final ObjectProfileRepository repository = ref.watch(objectProfileRepositoryProvider);
    final StreamSubscription<void> subscription = repository.changes().listen((_) {
      state = repository.all();
    });
    ref.onDispose(subscription.cancel);
    return repository.all();
  }

  Future<void> save(StorageObject object) =>
      ref.read(objectProfileRepositoryProvider).save(object);

  Future<void> delete(String id) => ref.read(objectProfileRepositoryProvider).delete(id);
}

final NotifierProvider<ObjectLibraryNotifier, List<StorageObject>> objectLibraryProvider =
    NotifierProvider<ObjectLibraryNotifier, List<StorageObject>>(ObjectLibraryNotifier.new);
