import 'package:cluckfall_heights/data/local/local_store.dart';
import 'package:cluckfall_heights/domain/library/builtin_objects.dart';
import 'package:cluckfall_heights/domain/objects/storage_object.dart';

/// The object library: the twelve bundled definitions plus whatever the user has
/// written.
///
/// Built-in objects are not copied into the box on first run. Keeping them in code
/// means a corrected weight ships with an update instead of being frozen into
/// every existing installation, and it keeps the box holding only the user's own
/// work.
class ObjectProfileRepository {
  const ObjectProfileRepository(this._store);

  final LocalStore _store;

  List<StorageObject> custom() {
    final List<StorageObject> objects = [
      for (final Object? raw in _store.objectProfiles.values)
        if (raw != null) StorageObject.fromJson(LocalStore.asJson(raw)),
    ];
    objects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return objects;
  }

  /// Everything the user can place, custom profiles first so recent work is
  /// nearest the top of the library.
  List<StorageObject> all() => [...custom(), ...BuiltInObjects.all];

  StorageObject? byId(String id) {
    final StorageObject? builtIn = BuiltInObjects.byId(id);
    if (builtIn != null) return builtIn;
    final Object? raw = _store.objectProfiles.get(id);
    return raw == null ? null : StorageObject.fromJson(LocalStore.asJson(raw));
  }

  Future<void> save(StorageObject object) =>
      _store.objectProfiles.put(object.id, object.copyWith(builtIn: false).toJson());

  Future<void> delete(String id) => _store.objectProfiles.delete(id);

  /// Removes the user's own profiles. The bundled ones are not stored in the box
  /// and so come back untouched.
  Future<void> deleteAll() => _store.objectProfiles.clear();

  int get customCount => _store.objectProfiles.length;

  Stream<void> changes() => _store.objectProfiles.watch();
}
