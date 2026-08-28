import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether AppsFlyer could tell this install came from a tracked marketing
/// link, judged purely from the `af_status` field of its first response.
///
/// [unknown] until that response lands, which can take a few seconds after
/// launch and never happens at all without a network connection.
enum InstallOrigin {
  unknown,
  organic,
  nonOrganic;

  bool get isResolved => this != InstallOrigin.unknown;
}

/// Reports install attribution to AppsFlyer so its dashboard can tell organic
/// installs apart from ones a marketing link drove, without asking the app to
/// do anything beyond starting the SDK once.
///
/// This is attribution only, not user analytics: no in-app events are logged,
/// no advertising identifier is collected (see [AppsFlyerOptions.disableAdvertisingIdentifier]
/// below), and nothing here builds a profile of the person using the app. The
/// one fact this integration produces is organic-or-not, which
/// [installOriginProvider] reflects once the first response lands.
class AnalyticsService {
  AnalyticsService(this._ref);

  final Ref _ref;

  /// From the AppsFlyer dashboard for this app.
  static const String _devKey = 'PG6N5qRcCdbtsBJs7vTBre';

  /// Apple's numeric App Store id, without the "id" prefix, matching the
  /// listing in App Store Connect and configured for this app in the
  /// AppsFlyer dashboard.
  static const String _iosAppId = '6802356905';

  bool _started = false;

  /// Starts AppsFlyer once per app launch. Failures are swallowed on purpose:
  /// attribution is a reporting concern, and a missing connection or a
  /// misbehaving plugin must never be the reason the app fails to start.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    // AppsflyerSdk is a process-wide singleton. Starting it here with
    // advertising identifiers disabled would poison the gray-flow SDK.
    if (LoftConfig.grayCredentialsReady) return;

    try {
      final AppsFlyerOptions options = AppsFlyerOptions(
        afDevKey: _devKey,
        appId: _iosAppId,
        showDebug: kDebugMode,
        // No advertising identifier is collected, so this integration never
        // needs an App Tracking Transparency prompt: AppsFlyer still tells
        // organic installs apart from attributed ones using its other
        // signals, which is all this app asks it for.
        disableAdvertisingIdentifier: true,
      );

      final AppsflyerSdk sdk = AppsflyerSdk(options);
      sdk.onInstallConversionData(_handleConversionData);
      await sdk.initSdk(registerConversionDataCallback: true);
    } on Object {
      // Offline, misconfigured, or the plugin failed to attach to the native
      // SDK. Either way the app carries on exactly as it would without it.
    }
  }

  void _handleConversionData(dynamic response) {
    if (response is! Map<dynamic, dynamic>) return;
    final Object? payload = response['payload'];
    if (payload is! Map<dynamic, dynamic>) return;

    final Object? status = payload['af_status'];
    final InstallOrigin origin = switch (status) {
      'Non-organic' => InstallOrigin.nonOrganic,
      'Organic' => InstallOrigin.organic,
      _ => InstallOrigin.unknown,
    };
    _ref.read(installOriginProvider.notifier).state = origin;
  }
}

final Provider<AnalyticsService> analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref),
);

/// Set once AppsFlyer's first conversion-data response lands.
final StateProvider<InstallOrigin> installOriginProvider = StateProvider<InstallOrigin>(
  (ref) => InstallOrigin.unknown,
);
