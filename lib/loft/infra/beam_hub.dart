import 'dart:async';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/link_gate.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> loftBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging plumbing for the WebView route.
///
/// Push URL discipline (post fix for flutterfire#17991 / #18352):
///   * cold-start push destination has EXACTLY ONE source of truth — the
///     `flutter.cfh_cold_tap` slot written by `SceneDelegate` and drained
///     by `TapPathReader`. FCM's `getInitialMessage()` is never used for
///     routing because the iOS SDK could return the same message on the
///     next cold launch (or a stale one after a silent wake);
///   * `getInitialMessage()` IS still called exactly once per process for
///     its side effect: the SDK marks the launch payload as read, so the
///     next cold launch does not resurrect it. The returned message is
///     discarded — see [_ackInitialMessage];
///   * warm taps (app in background) land in [onDestination] when a live
///     WebView is registered. If no callback is registered we drop the
///     URL — writing it to persistent storage would make it re-open on
///     the next unrelated launch;
///   * [onDestination] ownership uses identity so a SpanPane that has been
///     replaced never clears a newer pane's callback on dispose.
class BeamHub {
  BeamHub(this._vault, {required this.enabled});

  final LoftVault _vault;
  final bool enabled;

  bool get isReady => _messaging != null;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<void>? _ackFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// Called by the router the moment it commits the SceneDelegate slot URL
  /// to a `PortalSpan`. Kept for backwards compatibility with call sites —
  /// no longer gates any FCM code path because the initial message is only
  /// consumed for its side effect (ack), never for routing.
  void markLaunchTapConsumed() {}

  /// Registers an owner-scoped listener for warm push destinations. The
  /// returned token must be passed to [releaseOnDestination] on dispose so
  /// a stale widget cannot wipe a newer pane's callback.
  Object registerOnDestination(void Function(String url) callback) {
    onDestination = callback;
    return callback;
  }

  /// Clears [onDestination] only if the caller still owns it (i.e. no other
  /// SpanPane has replaced it in the meantime).
  void releaseOnDestination(Object token) {
    if (identical(onDestination, token)) {
      onDestination = null;
    }
  }

  /// Kept for existing call sites in [LoftGuide]. Always resolves `false`:
  /// the returning-portal path used to stash the initial message into the
  /// warm queue, which is exactly what caused the "cold-launch replays the
  /// same push" bug. The single legitimate consumer of the initial message
  /// is [_ackInitialMessage], which discards it.
  Future<bool> warmupInitialTap() async {
    if (!enabled) return false;
    await _ackInitialMessage();
    return false;
  }

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Fire-and-forget acknowledgement of FCM's cached launch message so the
    // next cold launch does not receive the same payload again. The value
    // is intentionally discarded — routing is owned by the SceneDelegate
    // slot via TapPathReader.
    unawaited(_ackInitialMessage());

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
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Warm tap only: app already alive, a live SpanPane is expected. If
      // no callback is registered we drop the URL rather than persisting
      // it — otherwise the next unrelated cold launch would replay it and
      // open the "special" screen for a user who never asked for it.
      final url = _extract(message.data);
      final admitted = url == null ? null : LinkGate.admit(url);
      if (admitted == null) return;
      onDestination?.call(admitted.toString());
    });
    await _waitForApns();
    _token = await messaging.getToken();
  }

  /// Calls [FirebaseMessaging.getInitialMessage] exactly once per process
  /// and discards the result. The call is what makes the SDK forget the
  /// launch payload; without it, iOS caches the message across cold starts
  /// and the second launch (with no fresh tap) re-opens the same URL.
  Future<void> _ackInitialMessage() {
    return _ackFuture ??= (() async {
      try {
        final messaging = _messaging ?? FirebaseMessaging.instance;
        _messaging ??= messaging;
        await messaging.getInitialMessage().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
      } catch (_) {}
    })();
  }

  /// Extraction order verbatim from the brief:
  ///   flat: deep_link, target, url, deeplink, link
  ///   then the same keys inside nested `payload` and `data`.
  String? _extract(Map<String, dynamic> payload) {
    const keys = <String>['deep_link', 'target', 'url', 'deeplink', 'link'];
    for (final key in keys) {
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
