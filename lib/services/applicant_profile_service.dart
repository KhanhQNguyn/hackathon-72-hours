/// Wraps `sqflite` (structured applicant profile: name, phone, email,
/// CV file path) and `flutter_secure_storage` (sensitive PII fields
/// specifically — email, phone — within that profile). Split out from
/// `PreferencesService`, which keeps only simple settings. See spec.md
/// §1, §8.
class ApplicantProfileService {
  // TODO: getProfile() -> a profile model or null, resolving
  // email/phone from flutter_secure_storage and the rest from sqflite
  Future<Map<String, String>?> getProfile() {
    throw UnimplementedError('sqflite + flutter_secure_storage integration — spec.md §8');
  }

  // TODO: saveProfile(...) — writes name/CV file path to sqflite,
  // email/phone to flutter_secure_storage
  Future<void> saveProfile(Map<String, String> profile) {
    throw UnimplementedError('sqflite + flutter_secure_storage integration — spec.md §8');
  }
}
