import 'package:flutter_tts/flutter_tts.dart';

/// Wraps the `flutter_tts` plugin. Owns narration calls — every step the
/// flow takes is spoken through this service, never silently. See
/// spec.md §7 (WCAG 3.3.1 Error Identification — errors must be spoken,
/// not just logged or shown as text the user can't see).
class TtsService {
  final FlutterTts _flutterTts;

  TtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts() {
    // Sequential narration is required for turn-taking correctness in
    // the field-by-field loop (announce field -> wait -> listen) — a
    // later speak() must not overlap an in-progress one.
    _flutterTts.awaitSpeakCompletion(true);
  }

  /// `'en'` or `'vi'` — maps to the BCP-47 locale flutter_tts expects.
  Future<void> setLanguage(String languagePref) {
    final locale = languagePref == 'vi' ? 'vi-VN' : 'en-US';
    return _flutterTts.setLanguage(locale);
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }
}
