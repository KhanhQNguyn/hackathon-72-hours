import 'job_listing.dart';

/// Intent types the parser may return (milestone36).
class IntentType {
  static const String readListing = 'read_listing';
  static const String fillAndSubmit = 'fill_and_submit';
  static const String navigateToElement = 'navigate_to_element';
  static const String unrecognized = 'unrecognized';

  static const Set<String> all = {
    readListing,
    fillAndSubmit,
    navigateToElement,
    unrecognized,
  };
}

/// Structured result of intent parsing (milestone36). After the
/// confidence gate, a low-confidence or unknown intent is always
/// `IntentType.unrecognized`.
class IntentResult {
  final String intentType;
  final String? targetDescription;
  final double confidence;

  const IntentResult({
    required this.intentType,
    this.targetDescription,
    required this.confidence,
  });

  bool get isRecognized => intentType != IntentType.unrecognized;
}

/// Transcription of a job description posted as an image (milestone37).
class ImageTranscription {
  final String text;
  final double confidence;

  const ImageTranscription({required this.text, required this.confidence});
}

/// A job listing summarized from raw page text (milestone38).
class ListingSummary {
  final JobListing listing;
  final double confidence;

  const ListingSummary({required this.listing, required this.confidence});
}

/// One heading/body block of a structured PDF (milestone40).
class PdfSection {
  final String heading;
  final String body;

  const PdfSection({required this.heading, required this.body});
}

/// A field inferred from raw PDF text when the PDF has no AcroForm
/// (milestone40). `inferredType`: text | email | phone | file | unknown.
class InferredPdfField {
  final String label;
  final String inferredType;

  const InferredPdfField({required this.label, required this.inferredType});
}

class PdfStructure {
  final List<PdfSection> sections;
  final List<InferredPdfField> inferredFields;

  const PdfStructure({required this.sections, required this.inferredFields});
}
