import 'package:flutter/foundation.dart';

void loftTrace(String Function() message) {
  assert(() { debugPrint(message()); return true; }());
}
