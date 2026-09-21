import 'dart:developer' as developer;

/// Local debug logging only (Logcat + a lightweight in-app event log) —
/// not a production observability stack. See spec.md §3.
class Logger {
  static void log(String message) {
    developer.log(message, name: 'JobAccessAssist');
  }
}
