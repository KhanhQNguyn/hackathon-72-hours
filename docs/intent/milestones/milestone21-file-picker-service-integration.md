# Milestone 21 — `FilePickerService` + form-fill integration point

**One-line goal:** hand CV file attachment off to the native file picker, since browsers block scripts from programmatically setting `<input type="file">` for security reasons — this is not a bug to route around via JS.

## Project context
`02-spec.md` §1: *"Browsers block scripts from programmatically assigning a file to `<input type="file">` for security reasons — this is not a bug to work around via JS injection, it needs a native file-picker invoked instead."*

## Maps to plan.md task(s)
A7

## Preconditions
Milestone 16 (the per-field fill flow this plugs into)

## Files touched
- `lib/services/file_picker_service.dart` — edit
- `lib/orchestration/application_flow_fsm.dart` — edit (branch in the per-field loop)

## Implementation spec
- `Future<String?> pickCvFile()`: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'])`, returns the picked file's path, or `null` if cancelled.
- **Integration point:** when `FillingFormState`'s current field's detected `type` (from milestone 11's `getLabeledFields`) is `"file"`, the per-field loop (milestone 05) does **not** attempt `WebViewControllerService.fillField()` at all for that field — it calls `FilePickerService.pickCvFile()` instead, narrates the result ("Đã chọn file CV: [filename]"). To actually attach the picked file to the real `<input type="file">` on the page (JS still can't do this), use `flutter_inappwebview`'s native `onShowFileChooser` callback, which exists specifically for this — return the picked path from that callback. Wire this in `WebViewControllerService`'s WebView setup, not inside `form_filler.js`.

## Definition of Done
- [ ] Tapping a real `<input type="file">` field on a fixture page triggers the native file picker (not any JS-driven attempt)
- [ ] The selected file appears attached on the page afterward, verified by checking the input's displayed filename inside the WebView itself

## Size
S

## Correction (audit 2026-09-22)
The instruction above to wire `flutter_inappwebview`'s `onShowFileChooser`
cannot be followed as written: in `flutter_inappwebview` 6.1.5 /
`flutter_inappwebview_android` 1.1.3 the chooser is implemented natively
(`InAppWebViewChromeClient.onShowFileChooser`, which launches its own picker
intent) and exposes **no Dart callback**. So `triggerFileChooser()` (JS
`.click()` on the input) is the entire integration. The flow announces the
chooser before opening it and confirms afterwards via
`getFileInputName()` that a file was really attached. See
`audit-2026-09-22.md` §1.4(b).
