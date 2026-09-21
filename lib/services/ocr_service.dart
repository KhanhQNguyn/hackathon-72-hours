import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps `google_mlkit_text_recognition`. On-device OCR fallback used by
/// `PdfReaderService` when a PDF application form has no extractable
/// text layer (i.e. it's actually a scanned image). On-device, free, no
/// added API cost/latency vs. routing every scanned PDF through the
/// vision API. See spec.md §1, §6.
class OcrService {
  /// Runs ML Kit text recognition on a rendered page image at
  /// [imagePath] (milestone20). `TextRecognitionScript.latin` — the
  /// default — covers Vietnamese, which uses Latin script with
  /// diacritics.
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await recognizer.close();
    }
  }
}
