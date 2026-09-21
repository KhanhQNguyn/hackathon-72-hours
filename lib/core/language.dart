/// Language codes stored in `PreferencesService` and the locale strings
/// each downstream plugin expects (spec.md §6.1, §8).
class AppLanguage {
  static const String en = 'en';
  static const String vi = 'vi';
  static const String defaultCode = en;

  /// `speech_to_text` locale id.
  static String sttLocale(String code) => code == vi ? 'vi_VN' : 'en_US';

  /// `flutter_tts` language tag.
  static String ttsLocale(String code) => code == vi ? 'vi-VN' : 'en-US';
}
