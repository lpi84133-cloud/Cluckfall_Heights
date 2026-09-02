import 'dart:async';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/link_gate.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> loftBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging plumbing for the WebView route.
///
/// Push URL discipline:
///   * a tap belongs only to the launch it was made in — nothing must leak
///     into the next cold start;
///   * the router (LoftGuide) drains the SceneDelegate slot as its first
///     action and calls [markLaunchTapConsumed] once it has done so. From
///     that point on, [warmupInitialTap] must be a no-op even though FCM
///     still holds the same launch message in memory (double-open guard);
///   * warm taps land in [onDestination] when a live WebView is registered,
///     otherwise they queue via [LoftVault.stashPushUrl];
///   * [onDestination] ownership uses identity so a SpanPane that has been
///     replaced never clears a newer pane's callback on dispose.
class BeamHub {
  BeamHub(this._vault, {required this.enabled});

  final LoftVault _vault;
  final bool enabled;

  bool get isReady => _messaging != null;
  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;
  bool _launchTapConsumed = false;
  bool _initialTapDrained = false;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// Called by the router the moment it commits the SceneDelegate slot URL
  /// to a `PortalSpan`. After this, [warmupInitialTap] and the FCM initial
  /// message inside [boot] must not stash — those would double-open on the
  /// next launch.
  void markLaunchTapConsumed() {
    _launchTapConsumed = true;
    _initialTapDrained = true;
  }

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

  /// Fast, side-effect-only drain of FCM's cached launch message into the
  /// warm queue. No-op when the router already consumed the tap via the
  /// SceneDelegate slot. Returns whether the queue was fed by this call.
  Future<bool> warmupInitialTap() async {
    if (!enabled) return false;
    if (_launchTapConsumed || _initialTapDrained) return false;
    _initialTapDrained = true;
    try {
      final messaging = FirebaseMessaging.instance;
      _messaging ??= messaging;
      final initial = await messaging.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initial == null) return false;
      final url = _extract(initial.data);
      if (url == null) return false;
      final admitted = LinkGate.admit(url);
      if (admitted == null) return false;
      await _vault.stashPushUrl(admitted.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Drain FCM's cached initial message. Feeds the warm queue only when the
    // router has NOT already consumed the tap through the SceneDelegate
    // slot — otherwise the same launch would open twice (once from the slot,
    // once from FCM's copy of the same OS-delivered payload).
    if (!_launchTapConsumed && !_initialTapDrained) {
      _initialTapDrained = true;
      try {
        final initial = await messaging.getInitialMessage().timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
        if (initial != null) {
          final url = _extract(initial.data);
          final admitted = url == null ? null : LinkGate.admit(url);
          if (admitted != null) {
            await _vault.stashPushUrl(admitted.toString());
          }
        }
      } catch (_) {}
    }

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
      final admitted = url == null ? null : LinkGate.admit(url);
      if (admitted == null) return;
      final formatted = admitted.toString();
      final callback = onDestination;
      if (callback != null) {
        // Live SpanPane will load it in place; do NOT stash. Stashing here
        // would let a later returning launch pick the same URL up again.
        callback(formatted);
      } else {
        await _vault.stashPushUrl(formatted);
      }
    });
    await _waitForApns();
    _token = await messaging.getToken();
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
