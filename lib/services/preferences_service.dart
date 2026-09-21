import 'package:shared_preferences/shared_preferences.dart';

import '../core/language.dart';

/// Wraps `SharedPreferences`. Simple settings only — language
/// preference and last search query. Structured, sensitive applicant
/// data lives in `ApplicantProfileService` instead. See spec.md §8.
///
/// Every consumer (STT, TTS, UI) re-reads on each call rather than
/// caching, so a language change takes effect on the next call without an
/// app restart (milestone31).
class PreferencesService {
  static const String _languageKey = 'language_pref';
  static const String _lastSearchKey = 'last_search_query';

  Future<String> getLanguagePref() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    return stored == AppLanguage.vi ? AppLanguage.vi : AppLanguage.defaultCode;
  }

  Future<void> setLanguagePref(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languageKey,
      languageCode == AppLanguage.vi ? AppLanguage.vi : AppLanguage.en,
    );
  }

  Future<String?> getLastSearchQuery() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSearchKey);
  }

  Future<void> setLastSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSearchKey, query);
  }
}
