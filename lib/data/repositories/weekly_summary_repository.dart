import 'package:cluckfall_heights/data/local/local_store.dart';

/// Stores the short capture history behind the weekly stability summary.
///
/// Kept as its own key in the preferences box rather than inside
/// [AppPreferences]: this is a record of observed history, not a setting the
/// user chose.
class WeeklySummaryRepository {
  const WeeklySummaryRepository(this._store);

  static const String _key = 'weekly_stability_history';

  final LocalStore _store;

  List<Map<String, dynamic>> read() {
    final Object? raw = _store.preferences.get(_key);
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.map(LocalStore.asJson).toList(growable: false);
  }

  Future<void> write(List<Map<String, dynamic>> history) =>
      _store.preferences.put(_key, history);
}
