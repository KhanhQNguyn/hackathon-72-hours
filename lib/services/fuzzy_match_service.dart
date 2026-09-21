/// Matches STT text / saved applicant-profile fields against detected
/// form-field labels (e.g. via string-similarity/edit-distance), before
/// falling back to the OpenAI matching call. First line of defense
/// against transcription distortion and label-text variance across
/// sites. See spec.md §6.1, §6.
class FuzzyMatchService {
  // TODO: bestMatch(value, candidateLabels) -> the best-matching label,
  // or null if nothing clears a similarity threshold
  String? bestMatch(String value, List<String> candidateLabels) {
    throw UnimplementedError('fuzzy-match logic — plan.md Workstream C2');
  }
}
