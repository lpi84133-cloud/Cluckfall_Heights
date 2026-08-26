import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/app/router.dart';
import 'package:cluckfall_heights/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root of the application.
///
/// The theme mode comes from the stored preference, so the choice made in Settings
/// survives a restart. Locale is fixed to English: every string in the app is
/// written in English and there is no translation to fall back to.
class CluckfallHeightsApp extends ConsumerWidget {
  const CluckfallHeightsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Cluckfall Heights',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
