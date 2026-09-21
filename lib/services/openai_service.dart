import '../models/dom_snapshot.dart';

/// Wraps calls to the OpenAI API. See spec.md §1, §6 for the call types
/// this service is responsible for: intent parsing, image-to-text,
/// DOM-content filtering/summarization, PDF-text structuring, and
/// form-field matching. Prompts should take the target page's DOM
/// snapshot or PDF text as generic parameters rather than hardcoding one
/// portal's field names (spec.md §1).
class OpenAiService {
  // TODO: parseIntent(String transcript) -> structured request
  // (spec.md §6, "Intent Parsing")
  Future<void> parseIntent(String transcript) {
    throw UnimplementedError('OpenAI intent parsing — plan.md Workstream C1');
  }

  // TODO: imageToText(...) -> transcribed job-description text, for
  // images with no usable alt text (spec.md §6, "AI Filtering & Matching")
  Future<String> imageToText(Object imageBytesOrUrl) {
    throw UnimplementedError('OpenAI vision image-to-text — plan.md Workstream C1');
  }

  // TODO: filterAndSummarizeDom(DomSnapshot) -> narratable job-listing
  // summary, ads/nav chrome suppressed (spec.md §6, "AI Filtering & Matching")
  Future<String> filterAndSummarizeDom(DomSnapshot snapshot) {
    throw UnimplementedError('OpenAI DOM filtering/summarization — plan.md Workstream C1');
  }

  // TODO: structurePdfText(String rawPdfText) -> structured, navigable
  // form content (spec.md §6, "PDF Perception")
  Future<String> structurePdfText(String rawPdfText) {
    throw UnimplementedError('OpenAI PDF-text structuring — plan.md Workstream C1');
  }

  // TODO: matchFormField(...) -> best-matching detected form field
  // (spec.md §6, "Form-Fill Orchestrator")
  Future<String?> matchFormField(String applicantValue, List<String> detectedFieldLabels) {
    throw UnimplementedError('OpenAI form-field matching — plan.md Workstream C1');
  }
}
