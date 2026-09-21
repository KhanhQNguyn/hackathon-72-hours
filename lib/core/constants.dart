/// Command phrasing templates and confidence thresholds.
/// See spec.md §6.1 "Voice Command Intake".
class AppConstants {
  // TODO: constrained command phrasing templates (shorter, more
  // predictable utterances transcribe more reliably than open-ended
  // speech — spec.md §6.1).

  /// Starting value only — tune empirically against real device/mic
  /// behavior (spec.md §6.1, plan.md Workstream B3). Below this
  /// threshold, the caller should re-prompt rather than proceed.
  static const double sttConfidenceThreshold = 0.6;
}
