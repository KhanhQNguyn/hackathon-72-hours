/// Wraps `SharedPreferences`. Simple settings only — language
/// preference and last search query. Structured, sensitive applicant
/// data lives in `ApplicantProfileService` instead. See spec.md §8.
class PreferencesService {
  // TODO: getLanguagePref() / setLanguagePref(String) — drives STT
  // locale + TTS voice + UI text (spec.md §6.1)
  Future<String> getLanguagePref() {
    throw UnimplementedError('SharedPreferences integration — spec.md §8');
  }

  Future<void> setLanguagePref(String languageCode) {
    throw UnimplementedError('SharedPreferences integration — spec.md §8');
  }

  // TODO: getLastSearchQuery() / setLastSearchQuery(String)
  Future<String?> getLastSearchQuery() {
    throw UnimplementedError('SharedPreferences integration — spec.md §8');
  }
}
