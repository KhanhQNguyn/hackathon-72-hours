import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint;

/// Local debug logging only (Logcat + a lightweight in-app event log) —
/// not a production observability stack. See spec.md §3.
///
/// Uses both `dart:developer`'s `log()` (visible in DevTools' Logging
/// view) and `debugPrint` (visible directly in the `flutter run` console
/// / `adb logcat`'s "flutter" tag) — `developer.log()` alone does not
/// reliably surface in either place on every setup.
class Logger {
  static void log(String message) {
    developer.log(message, name: 'JobAccessAssist');
    debugPrint('[JobAccessAssist] $message');
  }
}
