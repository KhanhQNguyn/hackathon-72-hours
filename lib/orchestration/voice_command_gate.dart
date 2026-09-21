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
/// `ApplicationFlowFsm` so the FSM stays free of service dependencies and
/// this milestone doesn't touch the file other workstreams are editing.
///
/// Call [run] while the FSM is in `ListeningState`. A transcript below
/// `AppConstants.sttConfidenceThreshold` (or empty) is never forwarded:
/// the user is re-prompted and the FSM stays in `ListeningState`. After
/// [maxAttempts] failed attempts the flow raises `ErrorOccurred` rather
/// than listening forever (the trigger button is disabled outside `Idle`,
/// so the user could not otherwise recover).
class VoiceCommandGate {
  VoiceCommandGate({
    required this.fsm,
    required this.speech,
    required this.tts,
    required this.preferences,
    this.maxAttempts = 3,
  });

  final ApplicationFlowFsm fsm;
  final SpeechService speech;
  final TtsService tts;
  final PreferencesService preferences;
  final int maxAttempts;

  Future<void> run() async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final language = await preferences.getLanguagePref();

      final result = await _listenOrNull(language);
      if (result == null) return;

      final belowThreshold =
          result.confidence < AppConstants.sttConfidenceThreshold ||
          result.transcript.trim().isEmpty;
      if (!belowThreshold) {
        await fsm.transition(VoiceCommandRecognized(result.transcript));
        return;
      }

      Logger.log(
        'voice_gate: attempt $attempt/$maxAttempts rejected '
        '(confidence=${result.confidence}, "${result.transcript}")',
      );
      await tts.speak(repromptMessage(language));
    }

    await fsm.transition(
      const ErrorOccurred("Couldn't understand the voice command."),
    );
  }

  Future<VoiceCommandResult?> _listenOrNull(String language) async {
    try {
      return await speech.listen();
    } on SpeechUnavailableException catch (e) {
      Logger.log('voice_gate: $e');
      await tts.speak(speechUnavailableMessage(language));
      await fsm.transition(ErrorOccurred(e.message));
      return null;
    }
  }
}
