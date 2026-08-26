import 'package:cluckfall_heights/data/local/local_store.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';

/// Reads and writes saved structures.
///
/// Reads are synchronous because the box is already in memory once opened, which
/// keeps the builder screen free of loading states while the user is editing.
class StructureRepository {
  const StructureRepository(this._store);

  final LocalStore _store;

  /// Most recently changed first, which is the order the home screen wants.
  List<Structure> all() {
    final List<Structure> structures = [
      for (final Object? raw in _store.structures.values)
        if (raw != null) Structure.fromJson(LocalStore.asJson(raw)),
    ];
    structures.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return structures;
  }

  Structure? byId(String id) {
    final Object? raw = _store.structures.get(id);
    return raw == null ? null : Structure.fromJson(LocalStore.asJson(raw));
  }

  Future<void> save(Structure structure) =>
      _store.structures.put(structure.id, structure.toJson());

  Future<void> delete(String id) => _store.structures.delete(id);

  Future<void> deleteAll() => _store.structures.clear();

  int get count => _store.structures.length;

  /// Fires after every write, so the list screens can rebuild themselves.
  Stream<void> changes() => _store.structures.watch();
}
