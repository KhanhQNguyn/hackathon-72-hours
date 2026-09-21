/// Simplified representation of the WebView page's DOM — images (with
/// alt-text presence), heuristically-narrowed search/submit candidates,
/// every labeled form field, and visible text content. Produced by
/// `WebViewControllerService.readDom()`. See spec.md §5 "Heuristic
/// pre-filtering before AI selection", §6 "Web Content Perception".
class DomSnapshot {
  final List<DomImage> images;

  /// Short, ranked candidate list for the search field — capped top 5,
  /// sorted by `heuristicScore` descending (milestone10).
  final List<DomFormField> searchCandidates;

  /// Short, ranked candidate list for the submit button — capped top 3,
  /// sorted by `heuristicScore` descending (milestone11).
  final List<DomFormField> submitCandidates;

  /// Every other labeled form field (name, phone, email, etc.) —
  /// deliberately NOT score-filtered/capped, since every real field is
  /// potentially relevant to the fill loop (milestone11).
  final List<DomFormField> labeledFields;

  /// Visible text content, capped at 8000 characters (milestone12).
  final String visibleText;

  /// True if `visibleText` was truncated to fit the cap.
  final bool truncated;

  const DomSnapshot({
    required this.images,
    required this.searchCandidates,
    required this.submitCandidates,
    required this.labeledFields,
    required this.visibleText,
    required this.truncated,
  });
}

/// A single detected `<img>` element and whether it carries meaningful
/// alt text (spec.md §6, barrier #3/#4 — image-based job descriptions).
/// `hasAlt` is true only when `altText` is present and non-empty after
/// trimming — an explicitly empty `alt=""` (decorative) is `hasAlt:
/// false` by design, per milestone09.
class DomImage {
  final String src;
  final String? altText;
  final bool hasAlt;

  const DomImage({required this.src, this.altText, required this.hasAlt});
}

/// A single detected form-related element. One shared shape serves three
/// distinct roles (spec.md §5 "Heuristic pre-filtering before AI
/// selection"), populated differently depending on which list it's
/// found in:
/// - In `DomSnapshot.searchCandidates`/`submitCandidates`: `role`,
///   `heuristicScore`, and the raw attributes (`placeholder`,
///   `ariaLabel`, `name`) are populated by the heuristic ranking
///   (milestone10/11); `resolvedLabel`/`labelSource` are null.
/// - In `DomSnapshot.labeledFields`: `resolvedLabel`/`labelSource` are
///   populated by the label-resolution heuristic (milestone11);
///   `role`/`heuristicScore` are null (labeled fields aren't
///   score-filtered).
///
/// `elementId` corresponds to the `data-app-node-id` attribute the
/// injected JS tags onto the live element at read time (milestone10),
/// so `form_filler.js` (milestone15+) can re-locate the exact same
/// element later in the same page-load session.
class DomFormField {
  final String elementId;
  final String tag;
  final String? type;

  /// `'search'` | `'submit'` | `'text'` | `'unknown'` — populated for
  /// search/submit candidates only (milestone10).
  final String? role;
  final String? placeholder;
  final String? ariaLabel;
  final String? name;

  /// Populated for search/submit candidates only (milestone10/11).
  final int? heuristicScore;

  /// Populated for labeled fields only (milestone11).
  final String? resolvedLabel;

  /// How `resolvedLabel` was resolved — e.g. `'label_for'`,
  /// `'aria_label'`, `'placeholder'`, `'name'`, `'sibling_text'`.
  /// Populated for labeled fields only (milestone11).
  final String? labelSource;

  const DomFormField({
    required this.elementId,
    required this.tag,
    this.type,
    this.role,
    this.placeholder,
    this.ariaLabel,
    this.name,
    this.heuristicScore,
    this.resolvedLabel,
    this.labelSource,
  });

  factory DomFormField.fromJson(Map<String, dynamic> json) {
    return DomFormField(
      elementId: json['elementId'] as String,
      tag: json['tag'] as String,
      type: json['type'] as String?,
      role: json['role'] as String?,
      placeholder: json['placeholder'] as String?,
      ariaLabel: json['ariaLabel'] as String?,
      name: json['name'] as String?,
      heuristicScore: json['heuristicScore'] as int?,
      resolvedLabel: json['resolvedLabel'] as String?,
      labelSource: json['labelSource'] as String?,
    );
  }
}
