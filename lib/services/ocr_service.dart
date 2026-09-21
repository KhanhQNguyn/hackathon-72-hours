/// Wraps `google_mlkit_text_recognition`. On-device OCR fallback used by
/// `PdfReaderService` when a PDF application form has no extractable
/// text layer (i.e. it's actually a scanned image). On-device, free, no
/// added API cost/latency vs. routing every scanned PDF through the
/// vision API. See spec.md §1, §6.
class OcrService {
  // TODO: recognizeText(String imagePath) -> String — run ML Kit text
  // recognition on a rendered page image (plan.md Workstream A8)
  Future<String> recognizeText(String imagePath) {
    throw UnimplementedError('google_mlkit_text_recognition integration — plan.md Workstream A8');
  }
}
