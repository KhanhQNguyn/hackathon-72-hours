/// Simplified representation of the WebView page's DOM — images (with
/// alt-text presence), form fields (with labels), and visible text
/// content. Produced by `WebViewControllerService.readDom()`.
/// See spec.md §5, §6 "Web Content Perception".
class DomSnapshot {
  final List<DomImage> images;
  final List<DomFormField> formFields;
  final String visibleText;

  const DomSnapshot({
    required this.images,
    required this.formFields,
    required this.visibleText,
  });
}

/// A single detected `<img>` element and whether it carries meaningful
/// alt text (spec.md §6, barrier #3/#4 — image-based job descriptions).
class DomImage {
  final String src;
  final String? altText;

  const DomImage({required this.src, this.altText});
}

/// A single detected form field and its associated label/placeholder,
/// if any (spec.md §6, "Form-Fill Orchestrator").
class DomFormField {
  final String fieldId;
  final String? label;

  const DomFormField({required this.fieldId, this.label});
}
