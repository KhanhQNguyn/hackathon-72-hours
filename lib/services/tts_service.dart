import 'package:flutter_tts/flutter_tts.dart';

import '../core/language.dart';
import '../utils/logger.dart';
import 'preferences_service.dart';

/// Wraps the `flutter_tts` plugin. Owns narration calls — every step the
/// flow takes is spoken through this service, never silently. See
/// spec.md §7 (WCAG 3.3.1 Error Identification — errors must be spoken,
/// not just logged or shown as text the user can't see).
class TtsService {
  TtsService({required PreferencesService preferences, FlutterTts? tts})
    : _preferences = preferences,
      _tts = tts ?? FlutterTts();

  final PreferencesService _preferences;
  final FlutterTts _tts;
  bool _configured = false;

  // Serializes calls: `awaitSpeakCompletion` only orders a caller with
  // itself, so two un-awaited `speak()` calls could still overlap without
  // this chain (milestone30).
  Future<void> _queue = Future<void>.value();

  /// Completes once the utterance has finished playing.
  Future<void> speak(String text) {
    final next = _queue.then((_) => _speakNow(text));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> stop() => _tts.stop();

  Future<void> _speakNow(String text) async {
    if (text.trim().isEmpty) return;
    if (!_configured) {
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    // Re-read the preference every call so a language toggle applies to
    // the very next utterance (milestone31).
    final code = await _preferences.getLanguagePref();
    await _tts.setLanguage(AppLanguage.ttsLocale(code));
    Logger.log('tts: speak(${AppLanguage.ttsLocale(code)}) "$text"');
    await _tts.speak(text);
  }
}
