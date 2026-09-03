import 'dart:async';
import 'dart:io';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:cluckfall_heights/loft/core/loft_trace.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/lift_signal.dart';
import 'package:cluckfall_heights/loft/infra/link_gate.dart';
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

    // First action, before any network / attribution / boot call: read the
    // SceneDelegate cold-start slot. That slot is written only when the OS
    // launched us from a notification tap; if it has content, the tap is
    // authoritative for this launch and beats everything else — cache,
    // config, prior route. The router marks the tap consumed so FCM's copy
    // of the same launch message does not later stash it into the queue and
    // resurrect it on the NEXT launch.
    // Push is a trusted destination from the backend — never run the
    // OneLink / brand-host filter here. That filter is for tap / Universal
    // Links only. Dropping a push URL falls through to the cached config
    // landing and opens the test-site start page.
    final coldTap = LinkGate.admit(await TapPathReader.consume());
    if (coldTap != null) {
      await vault.saveRoute(SpanRoute.portal);
      notifications.markLaunchTapConsumed();
      await vault.consumePushUrl();
      unawaited(_backgroundDispatch());
      onProgress(1);
      return PortalSpan(coldTap.toString(), coldLaunch: true);
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

    // Priority for the WebView route (per the routing brief):
    //   queue → non-expired cache → config → expired cache → no-net.
    //
    // The queue is fed by three producers, all clearing on read:
    //   * warm `onMessageOpenedApp` when no live SpanPane is registered,
    //   * `warmupInitialTap()` — a fast one-shot drain of FCM's cached
    //     cold-start launch message (skipped if the router already
    //     consumed the SceneDelegate slot),
    //   * `_boot()` — the same drain, only reached if the returning path
    //     never got as far as [warmupInitialTap].
    await notifications.warmupInitialTap();
    final queued = LinkGate.admit(await vault.consumePushUrl());
    if (queued != null) {
      await vault.saveRoute(SpanRoute.portal);
      notifications.markLaunchTapConsumed();
      progress(1);
      return PortalSpan(queued.toString(), coldLaunch: true);
    }

    final cachedRaw = await vault.savedUrl();
    final cached = LinkGate.admit(cachedRaw);
    if (cached != null && !vault.cachedUrlExpired) {
      progress(1);
      return PortalSpan(cached.toString());
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
    final fresh = reply.hasDestination ? LinkGate.admit(reply.url) : null;
    if (fresh != null) return PortalSpan(fresh.toString());
    if (cached != null) return PortalSpan(cached.toString());
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
