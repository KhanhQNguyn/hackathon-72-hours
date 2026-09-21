import 'dart:io';

import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/pdf_form_field.dart';
import 'ocr_service.dart';
import 'pdf_parse_exception.dart';

/// Wraps `syncfusion_flutter_pdf`. Extracts text/field structure from an
/// application-form PDF, distinguishing form-field structure from body
/// text where possible. Falls back to `OcrService` when no extractable
/// text layer is found (i.e. the PDF is actually a scanned image, not
/// real text) — see spec.md §1, §6 "PDF Perception".
///
/// **PDF-page rasterization (milestone20):** `google_mlkit_text_recognition`
/// takes an image, not a PDF page directly, and the milestone's own
/// recommended default — rendering via `flutter_inappwebview` + a
/// screenshot — turned out to need a live widget/`BuildContext` to host
/// an off-screen WebView, which this plain service class doesn't have
/// (confirmed with the team; see the `pdfx` entry in `pubspec.yaml` and
/// `02-spec.md` §1). Uses `pdfx` instead — headless, fits this class's
/// existing shape, at the cost of a third PDF-handling dependency
/// alongside `syncfusion_flutter_pdf`.
class PdfReaderService {
  final OcrService _ocrService;

  PdfReaderService({OcrService? ocrService})
      : _ocrService = ocrService ?? OcrService();

  /// Cheap text-layer check on page 1 only (milestone18): a real
  /// text-layer PDF's first page will almost always exceed 20 trimmed
  /// characters even if sparse; a scanned-image PDF returns empty or
  /// near-empty text.
  Future<bool> hasTextLayer(String pdfPath) async {
    final document = PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    try {
      final text = PdfTextExtractor(
        document,
      ).extractText(startPageIndex: 0, endPageIndex: 0);
      return text.trim().length >= 20;
    } finally {
      document.dispose();
    }
  }

  /// Full-document text extraction (milestone18). **Precondition:** only
  /// call this after [hasTextLayer] has returned `true` — an empty
  /// result here is not a meaningful signal for a scanned PDF, that
  /// ambiguity is exactly what [hasTextLayer] exists to resolve upfront.
  /// Most callers should use [extractTextWithOcrFallback] instead, which
  /// enforces this ordering.
  Future<String> extractText(String pdfPath) async {
    final document = PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  /// AcroForm field enumeration (milestone19) — only meaningful if the
  /// PDF actually has a real fillable-form layer. Returns `[]` for a
  /// text-only PDF with no AcroForm (common for "print and fill by hand"
  /// forms) — an expected, normal outcome, not an error.
  Future<List<PdfFormField>> extractFormFields(String pdfPath) async {
    final document = PdfDocument(inputBytes: await File(pdfPath).readAsBytes());
    try {
      final fields = document.form.fields;
      return [for (var i = 0; i < fields.count; i++) _toPdfFormField(fields[i])];
    } finally {
      document.dispose();
    }
  }

  PdfFormField _toPdfFormField(PdfField field) {
    final name = field.name ?? '';
    if (field is PdfTextBoxField) {
      return PdfFormField(name: name, type: 'text', value: field.text);
    }
    if (field is PdfCheckBoxField) {
      return PdfFormField(
        name: name,
        type: 'checkbox',
        value: field.isChecked.toString(),
      );
    }
    if (field is PdfComboBoxField) {
      return PdfFormField(name: name, type: 'combobox', value: field.selectedValue);
    }
    if (field is PdfListBoxField) {
      return PdfFormField(
        name: name,
        type: 'listbox',
        value: field.selectedValues.join(', '),
      );
    }
    if (field is PdfRadioButtonListField) {
      return PdfFormField(
        name: name,
        type: 'radio',
        value: field.selectedIndex.toString(),
      );
    }
    if (field is PdfSignatureField) {
      return PdfFormField(name: name, type: 'signature');
    }
    return PdfFormField(name: name, type: 'unknown');
  }

  /// The single method the rest of the app should call (milestone20) —
  /// never [extractText] directly, so the OCR fallback can never be
  /// accidentally bypassed. Checks [hasTextLayer] first; if `true`, uses
  /// the fast direct-extraction path; otherwise (or if direct extraction
  /// still fails despite that check) rasterizes page 1 and routes
  /// through [OcrService.recognizeText]. Throws [PdfParseException]
  /// (milestone23) only when **both** paths genuinely fail.
  Future<String> extractTextWithOcrFallback(String pdfPath) async {
    var hasText = false;
    try {
      hasText = await hasTextLayer(pdfPath);
    } catch (_) {
      // Treat a corrupted/unreadable PDF the same as "no text layer" —
      // fall through to the OCR path rather than failing immediately.
    }

    if (hasText) {
      try {
        return await extractText(pdfPath);
      } catch (_) {
        // Direct extraction failed despite hasTextLayer()'s cheap check
        // — fall through to OCR as a last resort rather than giving up.
      }
    }

    String? imagePath;
    try {
      imagePath = await _rasterizeFirstPage(pdfPath);
      final text = await _ocrService.recognizeText(imagePath);
      if (text.trim().isNotEmpty) return text;
    } catch (_) {
      // OCR fallback also failed — falls through to the throw below.
    } finally {
      if (imagePath != null) {
        final tempFile = File(imagePath);
        if (await tempFile.exists()) await tempFile.delete();
      }
    }

    throw const PdfParseException(
      'could not read this PDF — both direct text extraction and the '
      'OCR fallback failed',
    );
  }

  /// Renders page 1 of [pdfPath] to a temporary JPEG via `pdfx`, at 2x
  /// the PDF's own page resolution for better OCR accuracy. Caller owns
  /// deleting the returned temp file.
  Future<String> _rasterizeFirstPage(String pdfPath) async {
    final document = await pdfx.PdfDocument.openFile(pdfPath);
    try {
      final page = await document.getPage(1);
      try {
        final image = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        if (image == null) {
          throw const PdfParseException('PDF page rasterization failed');
        }
        final tempFile = File(
          '${Directory.systemTemp.path}/job_access_assist_ocr_'
          '${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(image.bytes);
        return tempFile.path;
      } finally {
        await page.close();
      }
    } finally {
      await document.close();
    }
  }
}
