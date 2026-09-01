import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Cold-start push destination bridge.
///
/// SceneDelegate writes the push URL into UserDefaults under `flutter.cfh_cold_tap`;
/// this reads it once and clears the slot. Matches HenheavenDash — a single
/// slot, no host filter (push URLs are backend-signed, not attribution links).
class TapPathReader {
  static const String _dartKey = 'cfh_cold_tap';

  /// Scene-Manifest race: FlutterEngine can reach `consume()` before
  /// `scene:willConnectToSession:` has written the URL. One empty read is
  /// not proof that SceneDelegate will stay silent. Short poll closes that
  /// window. See flutterfire#17991 / #18352.
  static const int _passes = 9;
  static const Duration _gap = Duration(milliseconds: 45);

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      for (var pass = 0; pass < _passes; pass++) {
        await preferences.reload();
        final value = preferences.getString(_dartKey)?.trim();
        if (value != null && value.isNotEmpty) {
          await preferences.remove(_dartKey);
          return value;
        }
        if (pass < _passes - 1) {
          await Future<void>.delayed(_gap);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
