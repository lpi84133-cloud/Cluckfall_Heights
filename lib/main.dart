import 'package:cluckfall_heights/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation is declared per platform rather than here: portrait everywhere
  // except iPad, which also keeps landscape. Doing it natively means the very
  // first frame is already in the right orientation.
  runApp(const ProviderScope(child: CluckfallHeightsApp()));
}
