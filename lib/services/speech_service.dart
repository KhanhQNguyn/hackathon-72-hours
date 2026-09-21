import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/language.dart';
import '../models/voice_command_result.dart';
import '../utils/logger.dart';
import 'preferences_service.dart';

/// Thrown when the platform recognizer can't start (mic permission
/// denied, no recognition service installed).
class SpeechUnavailableException implements Exception {
  final String message;
  const SpeechUnavailableException(this.message);

  @override
  String toString() => 'SpeechUnavailableException: $message';
}

/// Wraps the `speech_to_text` plugin. Owns locale selection (en_US/vi_VN,
/// driven by the user's language preference). Confidence-threshold gating
/// deliberately lives outside this class (`VoiceCommandGate`, milestone29)
/// so this service stays a plain "what did the mic hear" wrapper.
/// See spec.md §6.1 "Voice Command Intake".
class SpeechService {
  SpeechService({
    required PreferencesService preferences,
    SpeechToText? speech,
    this.listenFor = const Duration(seconds: 30),
    this.pauseFor = const Duration(seconds: 3),
  }) : _preferences = preferences,
       _speech = speech ?? SpeechToText();

  final PreferencesService _preferences;
  final SpeechToText _speech;
  final Duration listenFor;
  final Duration pauseFor;

  Completer<VoiceCommandResult>? _pending;

  static const VoiceCommandResult _empty = VoiceCommandResult(
    transcript: '',
    confidence: 0.0,
    alternatives: [],
  );

  /// Listens for one utterance and returns it. Silence or a recognizer
  /// error yields an empty transcript with confidence 0.0 (so the caller
  /// re-prompts) rather than throwing; only an unavailable recognizer
  /// throws [SpeechUnavailableException].
  Future<VoiceCommandResult> listen() async {
    final available = await _speech.initialize(
      onError: _onError,
      onStatus: (status) => Logger.log('stt: status=$status'),
    );
    if (!available) {
      throw const SpeechUnavailableException(
        'speech recognition unavailable (permission denied or no recognizer)',
      );
    }

    // Re-read every call so a language toggle applies to the next listen.
    final languageCode = await _preferences.getLanguagePref();
    final localeId = AppLanguage.sttLocale(languageCode);
    final completer = Completer<VoiceCommandResult>();
    _pending = completer;

    Logger.log('stt: listen(localeId=$localeId)');
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(_toResult(result));
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: false,
        cancelOnError: true,
      ),
    );

    try {
      return await completer.future.timeout(
        listenFor + const Duration(seconds: 5),
        onTimeout: () => _empty,
      );
    } finally {
      _pending = null;
      await _speech.stop();
    }
  }

  void _onError(SpeechRecognitionError error) {
    Logger.log('stt: error ${error.errorMsg} (permanent=${error.permanent})');
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(_empty);
  }

  VoiceCommandResult _toResult(SpeechRecognitionResult result) {
    // Android often reports no confidence at all (-1). Treating that as
    // 0.0 would make the threshold gate reject every utterance and the
    // app unusable on those devices, so "unavailable" is passed through as
    // 1.0 — the per-field confirm loop and submit checkpoint still catch
    // misheard input downstream.
    final confidence = result.hasConfidenceRating
        ? result.confidence.clamp(0.0, 1.0)
        : 1.0;
    return VoiceCommandResult(
      transcript: result.recognizedWords,
      confidence: confidence,
      alternatives: result.alternates.map((a) => a.recognizedWords).toList(),
    );
  }
}
