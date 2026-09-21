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

  /// Below this, an intent parsed by the model is treated as
  /// `unrecognized` (milestone36) — same starting value as the STT
  /// threshold; tune empirically.
  static const double intentConfidenceThreshold = 0.6;

  /// Below this, an element match is NOT acted on — the user is asked to
  /// disambiguate (milestone39). Higher than the STT threshold because a
  /// wrong click/fill is harder to notice than a misheard word. Starting
  /// value; tune empirically.
  static const double elementMatchConfidenceThreshold = 0.7;

  /// Minimum Levenshtein similarity ratio for `FuzzyMatchService`
  /// (milestone41).
  static const double fuzzyMatchThreshold = 0.6;
}
