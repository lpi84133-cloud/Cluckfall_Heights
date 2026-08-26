import 'package:cluckfall_heights/app/app.dart';
import 'package:cluckfall_heights/core/widgets/progress_track.dart';
import 'package:cluckfall_heights/features/bootstrap/bootstrap_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app boots into the loading screen with its own theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CluckfallHeightsApp()));
    await tester.pump();

    // Both bars are present from the first frame, in the portrait arrangement the
    // default test window falls into.
    expect(find.byType(ProgressTrack), findsOneWidget);
    expect(find.byType(VerticalProgressTrack), findsOneWidget);

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'Manrope');
    expect(app.debugShowCheckedModeBanner, isFalse);

    // Let the startup timeout elapse so no timer is left running at teardown.
    await tester.pump(BootstrapController.stepTimeout + const Duration(seconds: 1));
  });

  testWidgets('a stalled startup step is reported instead of holding the bar', (
    tester,
  ) async {
    // The platform channel that hands out the storage directory never answers in
    // a test binding, so the first step hangs here exactly as it would on a device
    // with a wedged file system. That is the case worth pinning down: the screen
    // gives up and says so rather than sitting at a percentage forever.
    await tester.pumpWidget(const ProviderScope(child: CluckfallHeightsApp()));
    await tester.pump();

    expect(find.text('Opening your local data'), findsOneWidget);
    expect(find.text('Startup did not finish'), findsNothing);

    await tester.pump(BootstrapController.stepTimeout + const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Startup did not finish'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
