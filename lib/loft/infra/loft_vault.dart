import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoftVault {
  static const String _routeKey = 'cfh.loft.route';
  static const String _expiryKey = 'cfh.loft.expiry';
  static const String _savedAtKey = 'cfh.loft.saved_at';
  static const String _inviteKey = 'cfh.loft.invite.after';
  static const String _inviteResolvedKey = 'cfh.loft.invite.resolved';
  static const String _permissionKey = 'cfh.loft.push.allowed';
  static const String _osDeniedKey = 'cfh.loft.push.os_denied';
  static const String _savedUrlKey = 'cfh.loft.secure.destination';
  static const String _pendingUrlKey = 'cfh.loft.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  SpanRoute get route => SpanRoute.parse(_preferences.getString(_routeKey));

  Future<void> saveRoute(SpanRoute route) =>
      _preferences.setString(_routeKey, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _savedUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _savedUrlKey, value: url);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _preferences.setInt(_savedAtKey, now);
      final expiry =
          expiresAt ?? now + LoftConfig.savedUrlExpiryDays * 86400;
      await _preferences.setInt(_expiryKey, expiry);
    } catch (_) {}
  }

  bool get cachedUrlExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiry = _preferences.getInt(_expiryKey);
    if (expiry == null || now >= expiry) return true;
    final savedAt = _preferences.getInt(_savedAtKey);
    if (savedAt != null &&
        now - savedAt >= LoftConfig.savedUrlExpiryDays * 86400) {
      return true;
    }
    return false;
  }

  Future<void> stashPushUrl(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _secure.write(key: _pendingUrlKey, value: url.trim());
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _pendingUrlKey);
      if (value != null) await _secure.delete(key: _pendingUrlKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _preferences.getBool(_permissionKey) ?? false;
  bool get pushDeniedByOs => _preferences.getBool(_osDeniedKey) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _preferences.setBool(_permissionKey, value);

  Future<void> markPushDeniedByOs() => _preferences.setBool(_osDeniedKey, true);

  /// Accept once = never show again, regardless of what the OS did with the
  /// prompt. Skip = come back exactly [_inviteKey] seconds later.
  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    if (_preferences.getBool(_inviteResolvedKey) ?? false) return false;
    final after = _preferences.getInt(_inviteKey);
    return after == null ||
        DateTime.now().millisecondsSinceEpoch ~/ 1000 >= after;
  }

  /// User tapped Skip: hide the deck until [epochSeconds].
  Future<void> snoozePushInvite(int epochSeconds) =>
      _preferences.setInt(_inviteKey, epochSeconds);

  /// User tapped Accept — the deck is done for good, even if the OS
  /// dialog was denied or a debug reset flips [pushAllowed] back to false.
  Future<void> markPushInviteResolved() =>
      _preferences.setBool(_inviteResolvedKey, true);
}
