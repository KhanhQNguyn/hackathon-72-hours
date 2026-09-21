import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language.dart';
import '../../services/applicant_profile_service.dart';
import '../../services/file_picker_service.dart';
import '../../services/preferences_service.dart';
import '../../utils/logger.dart';

/// Language toggle (EN/VI) persisted via `PreferencesService`, plus the
/// reusable applicant-profile form persisted via `ApplicantProfileService`.
/// See spec.md §8 and milestones 31/33.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _Strings {
  final String title, language, profile, name, phone, email, cv, cvNone, save;
  final String saved, saveFailed, pickFailed;
  const _Strings({
    required this.title,
    required this.language,
    required this.profile,
    required this.name,
    required this.phone,
    required this.email,
    required this.cv,
    required this.cvNone,
    required this.save,
    required this.saved,
    required this.saveFailed,
    required this.pickFailed,
  });
}

const _en = _Strings(
  title: 'Settings',
  language: 'Language',
  profile: 'Applicant profile',
  name: 'Full name',
  phone: 'Phone number',
  email: 'Email',
  cv: 'Choose CV file',
  cvNone: 'No CV file selected',
  save: 'Save profile',
  saved: 'Profile saved',
  saveFailed: 'Could not save the profile',
  pickFailed: 'Could not open the file picker',
);

const _vi = _Strings(
  title: 'Cài đặt',
  language: 'Ngôn ngữ',
  profile: 'Hồ sơ ứng viên',
  name: 'Họ và tên',
  phone: 'Số điện thoại',
  email: 'Email',
  cv: 'Chọn tệp CV',
  cvNone: 'Chưa chọn tệp CV',
  save: 'Lưu hồ sơ',
  saved: 'Đã lưu hồ sơ',
  saveFailed: 'Không thể lưu hồ sơ',
  pickFailed: 'Không thể mở trình chọn tệp',
);

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _language = AppLanguage.defaultCode;
  String? _cvFilePath;
  bool _loaded = false;

  _Strings get _s => _language == AppLanguage.vi ? _vi : _en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = context.read<PreferencesService>();
    final profileService = context.read<ApplicantProfileService>();
    final language = await prefs.getLanguagePref();
    Map<String, String>? profile;
    try {
      profile = await profileService.getProfile();
    } catch (e) {
      Logger.log('settings: getProfile failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _language = language;
      _nameController.text = profile?['name'] ?? '';
      _phoneController.text = profile?['phone'] ?? '';
      _emailController.text = profile?['email'] ?? '';
      _cvFilePath = profile?['cvFilePath'];
      _loaded = true;
    });
  }

  Future<void> _setLanguage(String code) async {
    await context.read<PreferencesService>().setLanguagePref(code);
    if (!mounted) return;
    setState(() => _language = code);
  }

  Future<void> _pickCv() async {
    final picker = context.read<FilePickerService>();
    try {
      final path = await picker.pickCvFile();
      if (path != null && mounted) setState(() => _cvFilePath = path);
    } catch (e) {
      Logger.log('settings: pickCvFile failed: $e');
      _snack(_s.pickFailed);
    }
  }

  Future<void> _save() async {
    final service = context.read<ApplicantProfileService>();
    final profile = <String, String>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'cvFilePath': ?_cvFilePath,
    };
    try {
      await service.saveProfile(profile);
      _snack(_s.saved);
    } catch (e) {
      Logger.log('settings: saveProfile failed: $e');
      _snack(_s.saveFailed);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _languageOption(String code, String nativeName) {
    final selected = _language == code;
    // Label is the language's own name so a Vietnamese TalkBack user
    // recognizes it immediately (spec.md §7).
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: nativeName,
      excludeSemantics: true,
      child: ListTile(
        selected: selected,
        title: Text(nativeName),
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () => _setLanguage(code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    s.language,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _languageOption(AppLanguage.en, 'English'),
                _languageOption(AppLanguage.vi, 'Tiếng Việt'),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    s.profile,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: s.name),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: s.phone),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: s.email),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _pickCv, child: Text(s.cv)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_cvFilePath ?? s.cvNone),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _save, child: Text(s.save)),
              ],
            ),
    );
  }
}
