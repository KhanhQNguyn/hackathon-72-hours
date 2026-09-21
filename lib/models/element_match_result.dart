/// Result of matching a target description against a short, heuristically
/// narrowed candidate list (milestone39). `elementId == null` is a valid
/// answer: none of the candidates match.
class ElementMatchResult {
  final String? elementId;
  final double confidence;
  final String reasoning;
  final List<String> alternativeElementIds;

  const ElementMatchResult({
    required this.elementId,
    required this.confidence,
    required this.reasoning,
    this.alternativeElementIds = const [],
  });

  /// True only when there is a pick and it clears [threshold]; anything
  /// else must go to the user for disambiguation rather than being acted
  /// on (spec.md §6 "AI Filtering & Matching").
  bool isConfident(double threshold) =>
      elementId != null && confidence >= threshold;
}
