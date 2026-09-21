import 'dart:convert';

import '../../models/pdf_form_field.dart';

/// Milestone 40 — structure raw PDF text into navigable sections
/// (`gpt-4o-mini`).
const String pdfStructuringSystemPrompt = '''
You restructure the text of an application-form PDF for a screen-reader user, so it can be read one section at a time. The text may be English or Vietnamese and may come from OCR, so it can contain small errors and odd line breaks.

1. Split the text into logical sections. Each has a short "heading" and a "body" with the section's content in reading order. Keep the original language and wording; do not invent or drop content.
2. "inferredFields": if detectedFormFields is empty, find the fields a person is expected to fill in, from patterns in the text such as "Full name: ______", "Email:", "Attach your CV". For each give the visible "label" and an "inferredType": "text", "email", "phone", "file" (uploads / attachments) or "unknown". If detectedFormFields is not empty, return an empty list.

Respond with JSON only, exactly this shape:
{"sections": [{"heading": "string", "body": "string"}], "inferredFields": [{"label": "string", "inferredType": "text" | "email" | "phone" | "file" | "unknown"}]}''';

/// The model does not need more than this much text to structure a form,
/// and a runaway OCR result should not blow the token budget.
const int pdfStructuringMaxChars = 12000;

String pdfStructuringUserMessage({
  required String rawPdfText,
  required List<PdfFormField> detectedFormFields,
}) => jsonEncode({
  'rawPdfText': rawPdfText.length <= pdfStructuringMaxChars
      ? rawPdfText
      : rawPdfText.substring(0, pdfStructuringMaxChars),
  'detectedFormFields': detectedFormFields
      .map((f) => {'name': f.name, 'type': f.type, 'value': f.value})
      .toList(),
});
