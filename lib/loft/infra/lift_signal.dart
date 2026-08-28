import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_trace.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class LiftSignal {
  LiftSignal(this._agent);

  final SpanAgent _agent;
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _startFuture;
  Future<void>? _consentFuture;
  bool _delayOrganic = true;
  bool _deepLinkFound = false;
  Completer<void> _installReady = Completer<void>();
  Completer<void> _deepLinkReady = Completer<void>();
  int _generation = 0;

  /// True once AppsFlyer gave us an `af_status` (Organic or Non-organic).
  /// Empty / timed-out conversion is not a real decision.
  bool get hasConversionStatus {
    final status = _statusOf(_install);
    return status == 'organic' || status == 'non-organic';
  }

  bool get isNonOrganic {
    if (_deepLinkFound) return true;
    if (_paidFrom(_install) || _paidFrom(_reopen) || _paidFrom(_deepLink)) {
      return true;
    }
    return false;
  }

  Future<void> start() => _startFuture ??= _start();

  Future<void> requestConsent() => _consentFuture ??= _requestConsent();

  /// Drop a poisoned in-process conversion after an offline first launch
  /// so Retry can wait for a real AF answer instead of replaying failure.
  void recycleForRetry() {
    if (_startFuture == null && _install == null) return;
    _generation++;
    _startFuture = null;
    _sdk = null;
    _install = null;
    _reopen = null;
    _deepLink = null;
    _deepLinkFound = false;
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    _installReady = Completer<void>();
    _deepLinkReady = Completer<void>();
  }

  Future<void> _start() async {
    final generation = _generation;
    if (!LoftConfig.grayCredentialsReady) {
      _completeEmpty();
      return;
    }
    try {
      await requestConsent();
      if (generation != _generation) return;
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: LoftConfig.appsFlyerKey,
          appId: LoftConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 12,
        ),
      );
      _sdk = sdk;
      final oneLink = LoftConfig.oneLinkHost;
      sdk.setOneLinkCustomDomain(<String>[
        if (oneLink.isNotEmpty) oneLink,
        'cluckfallheights.com',
      ]);
      sdk.onInstallConversionData(_acceptInstall);
      sdk.onAppOpenAttribution((dynamic raw) {
        if (generation != _generation) return;
        _reopen = _flat(raw);
      });
      sdk.onDeepLinking((result) {
        if (generation != _generation) return;
        _deepLinkFound = result.status == Status.FOUND;
        final event = result.deepLink?.clickEvent;
        if (event != null) {
          _deepLink = Map<String, dynamic>.from(event);
        }
        if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
      });
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      loftTrace(() => '[CFH.LIFT] initialization failed: $error');
      _completeEmpty();
    }
  }

  Future<void> _requestConsent() async {
    if (!Platform.isIOS) return;
    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(LoftConfig.attPromptDelay);
    await _waitFrontmost();
    status = await AppTrackingTransparency.requestTrackingAuthorization();
    if (status == TrackingStatus.notDetermined) {
      await _waitFrontmost(requireResumed: true);
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  }

  Future<void> _waitFrontmost({bool requireResumed = false}) async {
    for (var tick = 0; tick < 22; tick++) {
      final state = WidgetsBinding.instance.lifecycleState;
      final ready =
          state == AppLifecycleState.resumed ||
          (!requireResumed && state == null);
      if (ready) return;
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  Future<void> _acceptInstall(dynamic raw) async {
    final generation = _generation;
    try {
      final envelope = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final envelopeStatus = envelope?['status']?.toString().toLowerCase();
      final received = _flat(raw);
      loftTrace(
        () =>
            '[CFH.LIFT] conversion envelope=$envelopeStatus '
            'af_status=${received['af_status']} '
            'media=${received['media_source']} keys=${received.keys.toList()}',
      );
      if (generation != _generation) return;
      if (envelopeStatus == 'failure' || _statusOf(received) == 'failure') {
        _install = <String, dynamic>{};
      } else if (_statusOf(received) == 'organic' && _delayOrganic) {
        await Future<void>.delayed(
          const Duration(seconds: LoftConfig.organicRecheckLag),
        );
        if (generation != _generation) return;
        _install = _preferAttributed(received, await _fetchGcd());
      } else {
        _install = received;
      }
    } catch (error) {
      loftTrace(() => '[CFH.LIFT] conversion parse error: $error');
      if (generation == _generation) _install = <String, dynamic>{};
    } finally {
      if (generation == _generation && !_installReady.isCompleted) {
        _installReady.complete();
      }
    }
  }

  Map<String, dynamic> _flat(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = <String, dynamic>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    void mergeNested(dynamic nested, {required bool overwrite}) {
      if (nested is! Map) return;
      for (final entry in nested.entries) {
        final key = entry.key.toString();
        if (overwrite || !map.containsKey(key)) {
          map[key] = entry.value;
        }
      }
    }

    mergeNested(map['payload'], overwrite: true);
    if (_statusOf(map) == null) {
      mergeNested(map['data'], overwrite: false);
    }
    return map;
  }

  Map<String, dynamic> _preferAttributed(
    Map<String, dynamic> original,
    Map<String, dynamic>? fetched,
  ) {
    if (fetched == null || fetched.isEmpty) return original;
    final flat = _flat(fetched);
    if (_paidFrom(flat)) return flat;
    if (_statusOf(flat) != null) return flat;
    return original;
  }

  static String? _statusOf(Map<String, dynamic>? map) {
    final raw = map?['af_status']?.toString().toLowerCase().replaceAll(' ', '');
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'nonorganic' || raw == 'non-organic') return 'non-organic';
    if (raw == 'organic') return 'organic';
    return raw;
  }

  static bool _paidFrom(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return false;
    if (_statusOf(map) == 'non-organic') return true;
    final media = map['media_source']?.toString().trim().toLowerCase();
    if (media != null &&
        media.isNotEmpty &&
        media != 'organic' &&
        media != 'none') {
      return true;
    }
    final campaign = map['campaign']?.toString().trim();
    return campaign != null && campaign.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      final base = LoftConfig.gcdBase.endsWith('/')
          ? LoftConfig.gcdBase
          : '${LoftConfig.gcdBase}/';
      final uri = Uri.parse(
        '${base}id${LoftConfig.iosStoreId}?device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${LoftConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _flat(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration? installTimeout,
    bool delayOrganic = true,
  }) async {
    _delayOrganic = delayOrganic;
    await start();
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        installTimeout ?? LoftConfig.firstSignalTimeout,
        onTimeout: () {},
      ),
      _deepLinkReady.future.timeout(
        LoftConfig.deepLinkWait,
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_install != null) body.addAll(_jsonSafe(_install!));
    if (_reopen != null) {
      _jsonSafe(_reopen!).forEach((key, value) {
        body.putIfAbsent(key, () => value);
      });
    }
    if (_deepLink != null) {
      _jsonSafe(_deepLink!).forEach((key, value) {
        body.putIfAbsent(key, () => value);
      });
    }

    body['af_id'] = await appsFlyerId() ?? body['af_id'] ?? '';
    body['bundle_id'] = LoftConfig.bundleId;
    body['os'] = 'iOS';
    body['store_id'] = LoftConfig.storeToken;
    body['locale'] = locale;
    if (pushToken != null &&
        pushToken.isNotEmpty &&
        LoftConfig.firebaseProjectNumber.isNotEmpty) {
      body['push_token'] = pushToken;
      body['firebase_project_id'] = LoftConfig.firebaseProjectNumber;
    }

    if (Platform.isIOS) {
      try {
        if (await AppTrackingTransparency.trackingAuthorizationStatus ==
            TrackingStatus.authorized) {
          final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body['sub_id_10'] = idfa;
          }
        }
      } catch (_) {}
    }

    loftTrace(() => '[CFH.LIFT] payload ${jsonEncode(body)}');
    return body;
  }

  /// One flat JSON object. Nested Maps (AF `payload` leftovers) are merged
  /// up so PHP sees `campaign` / `media_source` at the top level.
  static Map<String, dynamic> _jsonSafe(Map<String, dynamic> source) {
    final out = <String, dynamic>{};
    void absorb(Map<dynamic, dynamic> map) {
      map.forEach((rawKey, value) {
        final key = rawKey.toString();
        if (value is Map) {
          absorb(value);
          return;
        }
        if (out.containsKey(key)) return;
        if (value == null || value is num || value is bool || value is String) {
          out[key] = value;
        } else {
          out[key] = value.toString();
        }
      });
    }

    absorb(source);
    return out;
  }

  void _completeEmpty() {
    if (!_installReady.isCompleted) _installReady.complete();
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }
}
