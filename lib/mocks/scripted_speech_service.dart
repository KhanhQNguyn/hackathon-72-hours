import 'dart:async';

import '../models/voice_command_result.dart';
import '../services/speech_service.dart';
import '../utils/logger.dart';

/// Debug-only stand-in for `SpeechService` that plays back a fixed script
/// of "spoken" replies instead of using the real recognizer. For
/// demoing/verifying the flow live on a device when the on-device
/// recognizer itself is unreliable (real-target demo flow: some Android
/// OEM recognizers truncate longer utterances regardless of the app's
/// configured pause tolerance) — narration/TTS and the AI calls stay
/// real; only the "what did the mic hear" step is scripted. Once the
/// script is exhausted, further calls return silence like a real timeout
/// would, so the flow's own re-prompt/error handling still applies.
class ScriptedSpeechService implements SpeechService {
  ScriptedSpeechService(List<String> script) : _script = List.of(script);
  final List<String> _script;

  @override
  Future<VoiceCommandResult> listen() async {
    // A short delay so the UI's "listening" state is visible/audible for
    // a beat, instead of the reply appearing instantly.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_script.isEmpty) {
      Logger.log('scripted_speech: script exhausted, returning silence');
      return const VoiceCommandResult(
        transcript: '',
        confidence: 0.0,
        alternatives: [],
      );
    }
    final text = _script.removeAt(0);
    Logger.log('scripted_speech: "$text"');
    return VoiceCommandResult(
      transcript: text,
      confidence: 1.0,
      alternatives: [text],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
