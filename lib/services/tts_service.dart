/// Wraps the `flutter_tts` plugin. Owns narration calls — every step the
/// flow takes is spoken through this service, never silently. See
/// spec.md §7 (WCAG 3.3.1 Error Identification — errors must be spoken,
/// not just logged or shown as text the user can't see).
class TtsService {
  // TODO: initialize flutter_tts, set voice/locale from PreferencesService
  // TODO: speak(String text) — used for every narration step, not just checkpoints
  Future<void> speak(String text) {
    throw UnimplementedError('flutter_tts integration — plan.md Workstream B3');
  }
}
