/// Local debug logging only (Logcat + a lightweight in-app event log) —
/// not a production observability stack. See spec.md §3.
class Logger {
  // TODO: log(String message) — writes to Logcat and/or an in-app event
  // log, for debugging during the build only.
}
