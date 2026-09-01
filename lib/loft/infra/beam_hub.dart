import 'dart:async';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> loftBackgroundMessage(RemoteMessage _) async {}

class BeamHub {
  BeamHub(this._vault, {required this.enabled});

  final LoftVault _vault;
  final bool enabled;
  // Exposed so PermitDeck / LoadingScreen can await boot before asking
  // permission — otherwise `_messaging` is null and the deck is skipped.
  bool get isReady => _messaging != null;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Cold-start push tap redundancy: SceneDelegate is the primary path
    // (writes UserDefaults synchronously from the OS callback), but Firebase
    // also caches the tap in `getInitialMessage`. Stash it so nothing is lost
    // if SceneDelegate ever misses the callback (e.g. delayed scene wiring).
    // The pilot consumes the secure stash after ColdTapReader, so both slots
    // are cleared and cannot resurrect a URL on a plain relaunch.
    try {
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (initial != null) {
        final url = _extract(initial.data);
        if (url != null) await _vault.stashPushUrl(url);
      }
    } catch (_) {}

    try {
      FirebaseMessaging.onBackgroundMessage(loftBackgroundMessage);
    } catch (_) {}
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    messaging.onTokenRefresh.listen((value) {
      _token = value;
      onTokenChanged?.call(value);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final url = _extract(message.data);
      if (url == null) return;
      // Warm start: stash so a returning launch after the WebView is torn
      // down still picks the URL up via [LoftVault.consumePushUrl]. If the
      // WebView is already alive [onDestination] loads it in place.
      await _vault.stashPushUrl(url);
      onDestination?.call(url);
    });
    await _waitForApns();
    _token = await messaging.getToken();
  }

  String? _extract(Map<String, dynamic> payload) {
    for (final key in const <String>[
      'deep_link',
      'target',
      'url',
      'deeplink',
      'link',
    ]) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    for (final container in const <String>['payload', 'data']) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extract(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApns({int? attempts}) async {
    final messaging = _messaging;
    if (messaging == null) return;
    final rounds = attempts ?? LoftConfig.apnsPollAttempts;
    for (var attempt = 0; attempt < rounds; attempt++) {
      try {
        if ((await messaging.getAPNSToken())?.isNotEmpty ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(LoftConfig.apnsPollStep);
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled || _vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final status =
        (await messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() {
    return _permissionFuture ??= _performPermissionRequest().whenComplete(
      () => _permissionFuture = null,
    );
  }

  Future<bool> _performPermissionRequest() async {
    if (!enabled || _messaging == null) return false;
    final result = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final accepted =
        result.authorizationStatus == AuthorizationStatus.authorized ||
        result.authorizationStatus == AuthorizationStatus.provisional;
    await _vault.setPushAllowed(accepted);
    if (!accepted && result.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }
    if (accepted) {
      await _waitForApns(attempts: 14);
      _token = await _messaging!.getToken();
      if (_token?.isNotEmpty ?? false) onTokenChanged?.call(_token!);
    }
    return accepted;
  }
}
