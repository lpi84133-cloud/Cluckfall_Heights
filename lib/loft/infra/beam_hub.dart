import 'dart:async';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/link_gate.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> loftBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging plumbing for the WebView route.
///
/// Push URL discipline — two cooperating sources, never one:
///   * `SceneDelegate` parks the URL of the notification that launched the
///     process in `flutter.cfh_cold_tap`; the router drains it through
///     `TapPathReader` as its very first action and calls
///     [markLaunchTapConsumed]. That is the fast path;
///   * Firebase replays the same notification through
///     [FirebaseMessaging.getInitialMessage], which resolves
///     asynchronously — sometimes after the router has already read an
///     empty native slot. That replay is the SAFETY NET: it goes into the
///     one-shot queue ([LoftVault.stashPushUrl]) so the returning-portal
///     path can prefer it over the cached landing. Dropping it is what
///     stranded a tapped user on the partner start page;
///   * warm taps go straight into a live [onDestination] when a portal is
///     on screen, otherwise they queue for whichever surface opens next.
///     A tap can arrive while the loader is still up and the WebView does
///     not exist yet — the queue is what carries it across that gap;
///   * the queue is consumed on read, so a tapped URL can never outlive
///     the launch it belongs to;
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

  /// Told by the router that this launch already opened on the URL held in
  /// the native slot, so Firebase's replay of that same notification must
  /// not be queued again — it would re-open on the next launch.
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

  /// Drains Firebase's copy of the launch notification into the one-shot
  /// queue without waiting for the rest of [boot] (token, APNs, listeners).
  /// The returning-portal path awaits this before it is allowed to fall
  /// back to the cached landing: the push service answers asynchronously,
  /// so an empty native slot is not proof that no tap happened.
  ///
  /// No-op once the router has committed the native slot URL.
  Future<bool> warmupInitialTap() async {
    if (!enabled) return false;
    if (_launchTapConsumed || _initialTapDrained) return false;
    _initialTapDrained = true;
    return _queueLaunchMessage();
  }

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    // Subscribed before the first await so a tap that lands while the
    // launch message is still being fetched is not dropped on the floor.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Firebase replays the notification that opened the app here as well.
    // Only reached when the router did NOT already open on the native slot
    // and [warmupInitialTap] never ran; asking again after either would
    // queue the very same navigation twice.
    if (!_launchTapConsumed && !_initialTapDrained) {
      _initialTapDrained = true;
      await _queueLaunchMessage();
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
    await _waitForApns();
    _token = await messaging.getToken();
  }

  /// Asks Firebase for the notification that launched the process and parks
  /// it in the one-shot queue. Returns whether the queue was fed.
  Future<bool> _queueLaunchMessage() async {
    try {
      final messaging = _messaging ?? FirebaseMessaging.instance;
      _messaging ??= messaging;
      final initial = await messaging.getInitialMessage().timeout(
        LoftConfig.launchMessageBudget,
        onTimeout: () => null,
      );
      if (initial == null) return false;
      final url = _extract(initial.data);
      final admitted = url == null ? null : LinkGate.admit(url);
      if (admitted == null) return false;
      await _vault.stashPushUrl(admitted.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A tap either goes straight into a portal that is already on screen, or
  /// waits in the queue for the surface that opens next. Queueing is what
  /// covers the window where the loader is up and the WebView, which the
  /// URL would be handed to, has not been built yet.
  void _handleTap(RemoteMessage message) {
    final url = _extract(message.data);
    final admitted = url == null ? null : LinkGate.admit(url);
    if (admitted == null) return;
    final formatted = admitted.toString();
    final live = onDestination;
    if (live == null) {
      unawaited(_vault.stashPushUrl(formatted));
      return;
    }
    live(formatted);
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
