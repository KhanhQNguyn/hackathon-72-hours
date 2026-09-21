/// Wraps `syncfusion_flutter_pdf`. Extracts text/field structure from an
/// application-form PDF, distinguishing form-field structure from body
/// text where possible. Falls back to `OcrService` when no extractable
/// text layer is found (i.e. the PDF is actually a scanned image, not
/// real text) — see spec.md §1, §6 "PDF Perception".
class PdfReaderService {
  // TODO: extractText(String pdfPath) -> structured text/field content
  Future<String> extractText(String pdfPath) {
    throw UnimplementedError('syncfusion_flutter_pdf integration — plan.md Workstream A4');
  }

  // TODO: hasTextLayer(String pdfPath) -> bool — if false, the caller
  // should route to OcrService instead of treating this as a plain
  // parse failure (plan.md Workstream A8)
  Future<bool> hasTextLayer(String pdfPath) {
    throw UnimplementedError('PDF text-layer detection — plan.md Workstream A4');
  }
}
