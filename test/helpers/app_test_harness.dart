import 'package:cluckfall_heights/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers the bundled fonts with the test binding.
///
/// Without this, widget tests draw everything in the placeholder test font, which
/// makes golden files useless for judging typography. The same files the app
/// ships are loaded here, so a golden shows what a device shows.
Future<void> loadAppFonts() async {
  const Map<String, List<String>> families = {
    // A package-provided font is registered under a package-qualified family
    // name. Without this every icon in a golden renders as an empty box.
    'packages/lucide_icons_flutter/Lucide': [
      'packages/lucide_icons_flutter/assets/lucide.ttf',
    ],
    'Manrope': [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
    ],
    'Fraunces': [
      'assets/fonts/Fraunces-SemiBold.ttf',
      'assets/fonts/Fraunces-Bold.ttf',
    ],
  };

  for (final MapEntry<String, List<String>> family in families.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final String path in family.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

/// Wraps a widget in the real app theme at a fixed size, for goldens.
Widget themedHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  Size size = const Size(420, 900),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, devicePixelRatio: 1),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      home: child,
    ),
  );
}

/// Pumps a widget and waits for bundled images to decode.
///
/// Image decoding runs off the test's fake async zone, so without draining real
/// asynchrony the goldens capture empty boxes where the artwork should be.
Future<void> pumpAndDecode(WidgetTester tester, Widget widget, {Size? surface}) async {
  if (surface != null) {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(widget);
  for (int i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
  }
}
