/// Thrown by `PdfReaderService.extractTextWithOcrFallback()` only when
/// **both** the direct text-extraction path and the OCR fallback
/// (milestone20) genuinely fail — the final PDF-parse failure mode
/// (`02-spec.md` §3, milestone23).
class PdfParseException implements Exception {
  final String message;

  const PdfParseException(this.message);

  @override
  String toString() => 'PdfParseException: $message';
}
