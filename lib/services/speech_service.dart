import '../models/voice_command_result.dart';

/// Wraps the `speech_to_text` plugin. Owns locale selection (en-US/vi-VN,
/// driven by the user's language preference) and confidence-threshold
/// gating before a transcript is passed downstream.
/// See spec.md §6.1 "Voice Command Intake" for the full mitigation chain
/// this service is responsible for (locale pinning, confidence threshold,
/// n-best hypotheses).
class SpeechService {
  // TODO: initialize speech_to_text, set locale from PreferencesService
  // TODO: listen(), returning VoiceCommandResult with transcript/confidence/alternatives
  // TODO: confidence threshold check — below threshold, caller should re-prompt, not proceed
  Future<VoiceCommandResult> listen() {
    throw UnimplementedError('speech_to_text integration — plan.md Workstream B3');
  }
}
