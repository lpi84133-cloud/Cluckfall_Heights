import 'dart:async';
import 'dart:io';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:cluckfall_heights/loft/core/loft_trace.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/lift_signal.dart';
import 'package:cluckfall_heights/loft/infra/loft_post.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:cluckfall_heights/loft/infra/span_probe.dart';
import 'package:cluckfall_heights/loft/infra/tap_path_reader.dart';

class LoftGuide {
  LoftGuide({
    required this.vault,
    required this.probe,
    required this.attribution,
    required this.exchange,
    required this.notifications,
    required this.agent,
    required this.runtimeEnabled,
  });

  final LoftVault vault;
  final SpanProbe probe;
  final LiftSignal attribution;
  final LoftPost exchange;
  final BeamHub notifications;
  final SpanAgent agent;
  final bool runtimeEnabled;

  bool get enabled => runtimeEnabled && LoftConfig.grayCredentialsReady;

  Future<LoftDestination>? _decideFuture;

  Future<LoftDestination> decide({
    required void Function(double value) onProgress,
  }) => _decideFuture ??= _decide(
    onProgress: onProgress,
  ).whenComplete(() => _decideFuture = null);

  Future<LoftDestination> _decide({
    required void Function(double value) onProgress,
  }) async {
    if (!enabled) {
      loftTrace(
        () =>
            '[CFH.GUIDE] gate disabled runtime=$runtimeEnabled '
            'creds=${LoftConfig.grayCredentialsReady}',
      );
      onProgress(1);
      return const NativeSpan();
    }

    loftTrace(() => '[CFH.GUIDE] decide start route=${vault.route}');

    notifications.onTokenChanged = _refreshForToken;

    // Cold-start push tap resolution runs in two passes because SceneDelegate
    // and Firebase's launch-message plugin race each other on iOS:
    //   1. `TapPathReader.consume()` polls the UserDefaults slot the native
    //      SceneDelegate writes to. Fast when it wins, empty when the OS
    //      routes the tap through FirebaseMessaging swizzling instead.
    //   2. `notifications.consumeInitialTap()` drains FCM's cached launch
    //      message. Non-null only on a real kill-launched-from-push run.
    // Whichever wins, the URL goes straight to Portal and we do NOT fall
    // back to `savedUrl()` — the pushed destination beats the cached start.
    String? coldTap = await TapPathReader.consume();
    if (coldTap == null || isAttributionLink(coldTap)) {
      final fromFcm = await notifications.consumeInitialTap();
      if (fromFcm != null && !isAttributionLink(fromFcm)) {
        coldTap = fromFcm;
      }
    }
    if (coldTap != null && !isAttributionLink(coldTap)) {
      await vault.saveRoute(SpanRoute.portal);
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalSpan(coldTap, coldLaunch: true);
    }

    onProgress(0.12);
    return switch (vault.route) {
      SpanRoute.undecided => _firstDecision(onProgress),
      SpanRoute.portal => _returningPortal(onProgress),
      SpanRoute.native => _returningNative(onProgress),
    };
  }

  Future<LoftDestination> _firstDecision(void Function(double) progress) async {
    attribution.recycleForRetry();

    if (!await probe.hasInterface()) {
      loftTrace(() => '[CFH.GUIDE] first: no interface → quiet');
      return const QuietSpan(returnToNative: false);
    }
    progress(0.28);

    unawaited(
      Future<void>(() async {
        try {
          await notifications.boot();
        } catch (_) {}
      }),
    );

    if (!await _waitWhileInterfaceUp(attribution.requestConsent())) {
      loftTrace(() => '[CFH.GUIDE] first: dropped during ATT → quiet');
      return const QuietSpan(returnToNative: false);
    }
    progress(0.48);
    if (!await _waitWhileInterfaceUp(attribution.awaitSignals())) {
      loftTrace(() => '[CFH.GUIDE] first: dropped during AF → quiet');
      return const QuietSpan(returnToNative: false);
    }
    progress(0.72);

    LoftReply? reply;
    if (!await _waitWhileInterfaceUp(
      _requestConfig().then<void>((value) {
        reply = value;
      }),
    )) {
      loftTrace(() => '[CFH.GUIDE] first: dropped during config → quiet');
      return const QuietSpan(returnToNative: false);
    }
    progress(1);
    final resolved = reply ?? LoftReply.rejected('network_failure');
    loftTrace(
      () =>
          '[CFH.GUIDE] first: hasDest=${resolved.hasDestination} '
          'authoritative=${resolved.isAuthoritative} '
          'reason=${resolved.reason} url=${resolved.url}',
    );
    if (resolved.hasDestination) {
      await vault.saveRoute(SpanRoute.portal);
      return PortalSpan(resolved.url!);
    }
    if (!resolved.isAuthoritative || !await probe.hasInterface()) {
      loftTrace(
        () => '[CFH.GUIDE] first: no authoritative config → stay first',
      );
      return const QuietSpan(returnToNative: false);
    }
    await vault.saveRoute(SpanRoute.native);
    return const NativeSpan();
  }

  Future<bool> _waitWhileInterfaceUp(Future<void> work) async {
    var done = false;
    final tracked = work.whenComplete(() => done = true);
    while (!done) {
      if (!await probe.hasInterface()) return false;
      await Future.any<void>(<Future<void>>[
        tracked,
        Future<void>.delayed(const Duration(milliseconds: 320)),
      ]);
    }
    return probe.hasInterface();
  }

  Future<LoftDestination> _returningPortal(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      return const QuietSpan(returnToNative: false);
    }

    // Push URL wins over the cached start page. Order matters:
    //   1. Warm/foreground stash written by [BeamHub.onMessageOpenedApp].
    //   2. FCM launch-message (kill-tap that the SDK swizzled before the
    //      SceneDelegate slot could commit).
    // Only after both come up empty do we hand back the last known URL.
    String? pending = await vault.consumePushUrl();
    if (pending == null || pending.isEmpty) {
      final fromFcm = await notifications.consumeInitialTap();
      if (fromFcm != null && !isAttributionLink(fromFcm)) {
        pending = fromFcm;
        // Clear the stash [consumeInitialTap] just wrote so a subsequent
        // returning launch does not resurrect the same URL.
        await vault.consumePushUrl();
      }
    }
    if (pending != null && pending.isNotEmpty) {
      await vault.saveRoute(SpanRoute.portal);
      progress(1);
      return PortalSpan(pending, coldLaunch: true);
    }

    final cached = await vault.savedUrl();
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalSpan(cached);
    }

    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      return const QuietSpan(returnToNative: false);
    }
    progress(0.62);
    await attribution.awaitSignals(
      installTimeout: LoftConfig.returningSignalTimeout,
      delayOrganic: false,
    );
    final reply = await _requestConfig();
    progress(1);
    if (reply.hasDestination) return PortalSpan(reply.url!);
    if (cached != null && !vault.cachedUrlExpired) return PortalSpan(cached);
    return const QuietSpan(returnToNative: false);
  }

  Future<LoftDestination> _returningNative(
    void Function(double) progress,
  ) async {
    if (!await probe.hasInterface()) {
      progress(1);
      return const NativeSpan();
    }
    await Future.wait<void>(<Future<void>>[
      notifications.boot(),
      attribution.start(),
    ]);
    if (!await probe.canReachNetwork()) {
      progress(1);
      return const NativeSpan();
    }
    progress(0.55);
    await attribution.awaitSignals(
      installTimeout: LoftConfig.returningSignalTimeout,
      delayOrganic: false,
    );
    final reply = await _requestConfig();
    progress(1);
    loftTrace(
      () =>
          '[CFH.GUIDE] returning-native hasDest=${reply.hasDestination} '
          'nonOrg=${attribution.isNonOrganic}',
    );
    if (!reply.hasDestination) return const NativeSpan();
    await vault.saveRoute(SpanRoute.portal);
    return PortalSpan(reply.url!);
  }

  /// OneLink (including the branded app host) is attribution, not a WebView URL.
  static bool isAttributionLink(String raw) {
    final host = Uri.tryParse(raw)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host.endsWith('onelink.me')) return true;
    if (host == 'cluckfallheights.com' ||
        host.endsWith('.cluckfallheights.com')) {
      return true;
    }
    final branded = LoftConfig.oneLinkHost.toLowerCase();
    return branded.isNotEmpty && (host == branded || host.endsWith('.$branded'));
  }

  Future<LoftReply> _requestConfig({String? token}) async {
    final body = await attribution.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? notifications.token,
    );
    return exchange.request(body);
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait<void>(<Future<void>>[
        notifications.boot(),
        attribution.awaitSignals(),
      ]);
      await _requestConfig();
    } catch (_) {}
  }

  Future<void> _refreshForToken(String token) async {
    try {
      await _requestConfig(token: token);
    } catch (_) {}
  }
}
