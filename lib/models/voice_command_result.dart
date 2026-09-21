/// Transcript, confidence, and n-best alternatives returned by
/// `SpeechService`. See spec.md §6.1 "Voice Command Intake".
class VoiceCommandResult {
  final String transcript;
  final double confidence;
  final List<String> alternatives;

  const VoiceCommandResult({
    required this.transcript,
    required this.confidence,
    required this.alternatives,
  });
}
