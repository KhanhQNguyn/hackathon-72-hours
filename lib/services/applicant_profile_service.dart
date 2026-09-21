import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/logger.dart';

/// Wraps `sqflite` (structured applicant profile: name, CV file path) and
/// `flutter_secure_storage` (sensitive PII — email, phone — kept out of
/// the plain SQLite file). Split out from `PreferencesService`, which
/// keeps only simple settings. See spec.md §1, §8.
///
/// Profile map keys: `name`, `email`, `phone`, `cvFilePath`. Only keys
/// that have a non-empty stored value are present in [getProfile]'s result.
class ApplicantProfileService {
  ApplicantProfileService({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  static const String _table = 'applicant_profile';
  static const String _emailKey = 'applicant_email';
  static const String _phoneKey = 'applicant_phone';

  final FlutterSecureStorage _secure;
  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      '$dir/applicant_profile.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE $_table ('
        'id INTEGER PRIMARY KEY, name TEXT, cv_file_path TEXT)',
      ),
    );
    _db = db;
    return db;
  }

  /// Returns `null` when nothing has been saved yet (first run).
  Future<Map<String, String>?> getProfile() async {
    final db = await _database();
    final rows = await db.query(_table, where: 'id = 1', limit: 1);
    final email = await _secure.read(key: _emailKey);
    final phone = await _secure.read(key: _phoneKey);

    final profile = <String, String>{};
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String?;
      final cv = rows.first['cv_file_path'] as String?;
      if (name != null && name.isNotEmpty) profile['name'] = name;
      if (cv != null && cv.isNotEmpty) profile['cvFilePath'] = cv;
    }
    if (email != null && email.isNotEmpty) profile['email'] = email;
    if (phone != null && phone.isNotEmpty) profile['phone'] = phone;

    return profile.isEmpty && rows.isEmpty ? null : profile;
  }

  /// Writes the `sqflite` row first, then the two secure keys. There is no
  /// cross-engine transaction: if a secure write fails, the row is still
  /// valid and each field is independently useful (milestone32).
  Future<void> saveProfile(Map<String, String> profile) async {
    final db = await _database();
    await db.insert(_table, {
      'id': 1,
      'name': profile['name'],
      'cv_file_path': profile['cvFilePath'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _writeSecure(_emailKey, profile['email']);
    await _writeSecure(_phoneKey, profile['phone']);
    Logger.log('applicant_profile: saved (${profile.keys.join(', ')})');
  }

  Future<void> _writeSecure(String key, String? value) {
    if (value == null || value.isEmpty) return _secure.delete(key: key);
    return _secure.write(key: key, value: value);
  }
}
