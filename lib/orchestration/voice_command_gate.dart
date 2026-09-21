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
///
/// This is the only place `speech.listen()` is called, so it is also the
/// single source of the "microphone is open" signal: [onListeningChanged]
/// fires around that call, and (with [playCues]) a spoken cue is played as
/// it opens and, when speech was captured, when it closes. The mic button
/// and the audio cues therefore cannot drift apart.
class VoiceCommandGate {
  VoiceCommandGate({
    required this.fsm,
    required this.speech,
    required this.tts,
    required this.preferences,
    this.maxAttempts = 3,
    Future<void> Function(String text)? narrate,
    this.onListeningChanged,
    this.playCues = false,
  }) : _narrate = narrate;

  final ApplicationFlowFsm fsm;
  final SpeechService speech;
  final TtsService tts;
  final PreferencesService preferences;
  final int maxAttempts;
  final Future<void> Function(String text)? _narrate;

  /// Called with `true` just before the recognizer is opened and `false`
  /// as soon as it has returned.
  final void Function(bool listening)? onListeningChanged;

  /// Speak the start/stop cues around each listen.
  final bool playCues;

  /// The most recent utterance that cleared the threshold — its n-best
  /// alternatives feed intent parsing (milestone36).
  VoiceCommandResult? lastAccepted;

  /// True after the last [listenConfident] failed because the recognizer
  /// itself is unusable (permission denied / no recognizer), where asking
  /// the user to "say retry" cannot help.
  bool speechUnavailable = false;

  Future<void> _say(String text) => (_narrate ?? tts.speak)(text);

  /// Cues go straight to TTS, not through `narrate`, so they are not
  /// mirrored on screen as if they were content.
  Future<void> _cue(String text) async {
    if (!playCues) return;
    try {
      await tts.speak(text);
    } catch (e) {
      Logger.log('voice_gate: cue failed: $e');
    }
  }

  /// Listens until an utterance clears the confidence threshold and
  /// returns its transcript, re-prompting on each rejection. Returns
  /// `null` after [maxAttempts] rejections, or if the recognizer is
  /// unavailable (spoken explanation included). Does not touch the FSM.
  Future<String?> listenConfident() async {
    speechUnavailable = false;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final language = await preferences.getLanguagePref();
      final n = FlowNarration(language);

      final VoiceCommandResult result;
      onListeningChanged?.call(true);
      try {
        await _cue(n.micCueStart);
        result = await speech.listen();
      } on SpeechUnavailableException catch (e) {
        onListeningChanged?.call(false);
        Logger.log('voice_gate: $e');
        speechUnavailable = true;
        await _say(speechUnavailableMessage(language));
        return null;
      } finally {
        onListeningChanged?.call(false);
      }

      final belowThreshold =
          result.confidence < AppConstants.sttConfidenceThreshold ||
          result.transcript.trim().isEmpty;
      if (!belowThreshold) {
        lastAccepted = result;
        await _cue(n.micCueStop);
        return result.transcript;
      }

      Logger.log(
        'voice_gate: attempt $attempt/$maxAttempts rejected '
        '(confidence=${result.confidence}, "${result.transcript}")',
      );
      await _say(repromptMessage(language));
    }
    return null;
  }

  /// Call while the FSM is in `ListeningState`: forwards an accepted
  /// transcript as `VoiceCommandRecognized`, or raises `ErrorOccurred`
  /// with a message in the user's language.
  Future<void> run() async {
    final transcript = await listenConfident();
    if (transcript == null) {
      final n = FlowNarration(await preferences.getLanguagePref());
      await fsm.transition(
        ErrorOccurred(speechUnavailable ? n.errSpeechUnavailable : n.errVoice),
      );
      return;
    }
    await fsm.transition(VoiceCommandRecognized(transcript));
  }
}
