/// Wraps `file_picker`. Native CV file selection — browsers/WebViews
/// block scripts from programmatically setting `<input type="file">`
/// for security reasons, so this must be a native picker, not JS
/// injection (spec.md §1, §6; plan.md Workstream A7).
class FilePickerService {
  // TODO: pickCvFile() -> String? file path, handed back into the flow
  // for the relevant form field
  Future<String?> pickCvFile() {
    throw UnimplementedError('file_picker integration — plan.md Workstream A7');
  }
}
