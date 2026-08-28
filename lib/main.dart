import 'package:cluckfall_heights/app/app.dart';
import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/lift_signal.dart';
import 'package:cluckfall_heights/loft/infra/loft_post.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';
import 'package:cluckfall_heights/loft/infra/span_probe.dart';
import 'package:cluckfall_heights/loft/loft_guide.dart';
import 'package:cluckfall_heights/loft/loft_scope.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vault = LoftVault();
  final agent = SpanAgent();
  await Future.wait<void>(<Future<void>>[vault.initialize(), agent.prepare()]);

  var productionServicesReady = false;
  if (LoftConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      // Must be registered before runApp — calling it later from BeamHub
      // throws and LoadingScreen used to swallow that into the white game.
      FirebaseMessaging.onBackgroundMessage(loftBackgroundMessage);
    } catch (_) {}
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (_) {}
    }
  }

  final probe = SpanProbe();
  final notifications = BeamHub(vault, enabled: productionServicesReady);
  final attribution = LiftSignal(agent);
  final guide = LoftGuide(
    vault: vault,
    probe: probe,
    attribution: attribution,
    exchange: LoftPost(agent, vault),
    notifications: notifications,
    agent: agent,
    runtimeEnabled: LoftConfig.grayCredentialsReady,
  );

  // Orientation is declared per platform rather than here: portrait everywhere
  // except iPad, which also keeps landscape. Doing it natively means the very
  // first frame is already in the right orientation. Gray screens re-enable
  // landscape themselves.
  runApp(
    ProviderScope(
      overrides: <Override>[loftGuideProvider.overrideWithValue(guide)],
      child: const CluckfallHeightsApp(),
    ),
  );
}
