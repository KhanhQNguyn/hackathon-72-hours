import '../core/constants.dart';
import '../core/narration_lookup.dart';
import '../models/voice_command_result.dart';
import '../services/preferences_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../utils/logger.dart';
import 'application_flow_fsm.dart';

/// Confidence-threshold gate between `SpeechService` and the FSM
/// (milestone29). Lives in its own file rather than inside
/// `ApplicationFlowFsm` so the FSM stays free of service dependencies.
///
/// A transcript below `AppConstants.sttConfidenceThreshold` (or empty) is
/// never forwarded: the user is re-prompted. After [maxAttempts] failed
/// attempts the caller gets `null` (or, via [run], an `ErrorOccurred`)
/// rather than listening forever.
class VoiceCommandGate {
  VoiceCommandGate({
    required this.fsm,
    required this.speech,
    required this.tts,
    required this.preferences,
    this.maxAttempts = 3,
    Future<void> Function(String text)? narrate,
  }) : _narrate = narrate;

  final ApplicationFlowFsm fsm;
  final SpeechService speech;
  final TtsService tts;
  final PreferencesService preferences;
  final int maxAttempts;
  final Future<void> Function(String text)? _narrate;

  /// The most recent utterance that cleared the threshold — its n-best
  /// alternatives feed intent parsing (milestone36).
  VoiceCommandResult? lastAccepted;

  String _failureMessage = "Couldn't understand the voice command.";

  Future<void> _say(String text) => (_narrate ?? tts.speak)(text);

  /// Listens until an utterance clears the confidence threshold and
  /// returns its transcript, re-prompting on each rejection. Returns
  /// `null` after [maxAttempts] rejections, or if the recognizer is
  /// unavailable (spoken explanation included). Does not touch the FSM.
  Future<String?> listenConfident() async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final language = await preferences.getLanguagePref();

      final VoiceCommandResult result;
      try {
        result = await speech.listen();
      } on SpeechUnavailableException catch (e) {
        Logger.log('voice_gate: $e');
        _failureMessage = e.message;
        await _say(speechUnavailableMessage(language));
        return null;
      }

      final belowThreshold =
          result.confidence < AppConstants.sttConfidenceThreshold ||
          result.transcript.trim().isEmpty;
      if (!belowThreshold) {
        lastAccepted = result;
        return result.transcript;
      }

      Logger.log(
        'voice_gate: attempt $attempt/$maxAttempts rejected '
        '(confidence=${result.confidence}, "${result.transcript}")',
      );
      await _say(repromptMessage(language));
    }
    _failureMessage = "Couldn't understand the voice command.";
    return null;
  }

  /// Call while the FSM is in `ListeningState`: forwards an accepted
  /// transcript as `VoiceCommandRecognized`, or raises `ErrorOccurred`.
  Future<void> run() async {
    final transcript = await listenConfident();
    if (transcript == null) {
      await fsm.transition(ErrorOccurred(_failureMessage));
      return;
    }
    await fsm.transition(VoiceCommandRecognized(transcript));
  }
}
