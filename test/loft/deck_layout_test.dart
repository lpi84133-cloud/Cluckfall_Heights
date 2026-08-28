import 'package:cluckfall_heights/loft/infra/beam_hub.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_probe.dart';
import 'package:cluckfall_heights/loft/pages/permit_deck.dart';
import 'package:cluckfall_heights/loft/pages/quiet_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_test_harness.dart';

void main() {
  late LoftVault vault;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    vault = LoftVault();
    await vault.initialize();
  });

  Future<void> pumpDeck(
    WidgetTester tester, {
    required Size surface,
    required Widget child,
  }) async {
    await pumpAndDecode(
      tester,
      themedHarness(size: surface, child: child),
      surface: surface,
    );
  }

  testWidgets('2.7 permit portrait: centered Accept + Skip', (tester) async {
    const surface = Size(390, 844);
    await pumpDeck(
      tester,
      surface: surface,
      child: PermitDeck(
        vault: vault,
        notifications: BeamHub(vault, enabled: false),
        nextBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
    _expectCentered(tester, find.text('Accept'), surface);
    await expectLater(
      find.byType(PermitDeck),
      matchesGoldenFile('goldens/permit_portrait.png'),
    );
  });

  testWidgets('2.7 permit landscape: centered Accept + Skip, no SafeArea', (
    tester,
  ) async {
    const surface = Size(844, 390);
    await pumpDeck(
      tester,
      surface: surface,
      child: PermitDeck(
        vault: vault,
        notifications: BeamHub(vault, enabled: false),
        nextBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
    expect(find.byKey(const Key('permit-actions')), findsOneWidget);
    final accept = tester.getRect(find.text('Accept'));
    final skip = tester.getRect(find.text('Skip'));
    expect(accept.center.dx, lessThan(skip.center.dx));
    final mid = (accept.center.dx + skip.center.dx) / 2;
    expect((mid - surface.width / 2).abs(), lessThan(24));
    await expectLater(
      find.byType(PermitDeck),
      matchesGoldenFile('goldens/permit_landscape.png'),
    );
  });

  testWidgets('2.7 nowifi portrait: centered Retry via retryBuilder', (
    tester,
  ) async {
    const surface = Size(390, 844);
    await pumpDeck(
      tester,
      surface: surface,
      child: QuietDeck(
        probe: SpanProbe(),
        retryBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
    _expectCentered(tester, find.text('Retry'), surface);
    await expectLater(
      find.byType(QuietDeck),
      matchesGoldenFile('goldens/nowifi_portrait.png'),
    );
  });

  testWidgets('2.7 nowifi landscape: centered Retry, no SafeArea', (
    tester,
  ) async {
    const surface = Size(844, 390);
    await pumpDeck(
      tester,
      surface: surface,
      child: QuietDeck(
        probe: SpanProbe(),
        retryBuilder: (_) => const SizedBox.shrink(),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
    _expectCentered(tester, find.text('Retry'), surface);
    await expectLater(
      find.byType(QuietDeck),
      matchesGoldenFile('goldens/nowifi_landscape.png'),
    );
  });
}

void _expectCentered(WidgetTester tester, Finder label, Size surface) {
  final box = tester.getRect(label);
  final dx = (box.center.dx - surface.width / 2).abs();
  expect(dx, lessThan(24), reason: '$label is off-center by $dx');
}
