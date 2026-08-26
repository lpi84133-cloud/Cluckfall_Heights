import 'package:cluckfall_heights/data/local/local_store.dart';
import 'package:cluckfall_heights/domain/settings/app_preferences.dart';

/// Stores the whole settings object under a single key.
///
/// One record rather than a key per setting: settings are always read together,
/// and a single write cannot leave the app half-configured.
class PreferencesRepository {
  const PreferencesRepository(this._store);

  static const String _key = 'app';

  final LocalStore _store;

  AppPreferences read() {
    final Object? raw = _store.preferences.get(_key);
    if (raw == null) return const AppPreferences();
    return AppPreferences.fromJson(LocalStore.asJson(raw));
  }

  Future<void> write(AppPreferences preferences) =>
      _store.preferences.put(_key, preferences.toJson());

  Stream<void> changes() => _store.preferences.watch();
}
