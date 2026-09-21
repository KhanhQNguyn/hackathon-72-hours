import 'package:file_picker/file_picker.dart';

/// Wraps `file_picker`. Native CV file selection — browsers/WebViews
/// block scripts from programmatically setting `<input type="file">`
/// for security reasons, so this must be a native picker, not JS
/// injection (spec.md §1, §6; plan.md Workstream A7).
class FilePickerService {
  /// Opens the native file picker restricted to CV-shaped documents
  /// (milestone21). Returns the picked file's path, or `null` if the
  /// user cancelled.
  Future<String?> pickCvFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    return file?.path;
  }

  /// Native picker for the application-form PDF itself (milestone44) —
  /// the flow has no other way to obtain a PDF path on a real run. Returns
  /// the path, or `null` if cancelled.
  Future<String?> pickPdfFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    return file?.path;
  }
}
