import '../models/dom_snapshot.dart';

/// Dart side of the WebView + JS-bridge, backed by `flutter_inappwebview`
/// (spec.md §5). Loads the target page, injects `assets/js/dom_reader.js`
/// and `assets/js/form_filler.js` as `UserScript`s (`AT_DOCUMENT_START`,
/// so a `MutationObserver` attaches before the page's own scripts run),
/// and exposes DOM read/fill results back to Dart via a
/// `WebMessageListener` restricted to the loaded page's origin.
class WebViewControllerService {
  // TODO: loadTarget(String url) — hosts the target page in the
  // embedded WebView (plan.md Workstream A1, the core spike target)
  Future<void> loadTarget(String url) {
    throw UnimplementedError('flutter_inappwebview integration — plan.md Workstream A1');
  }

  // TODO: readDom() -> DomSnapshot, via dom_reader.js
  // (spec.md §5, §6 "Web Content Perception")
  Future<DomSnapshot> readDom() {
    throw UnimplementedError('DOM reading — plan.md Workstream A2');
  }

  // TODO: fillField(String fieldId, String value) -> bool, via
  // form_filler.js, with a re-read-to-verify step after filling
  // (spec.md §5, §6 "Form-Fill Orchestrator")
  Future<bool> fillField(String fieldId, String value) {
    throw UnimplementedError('form-filling — plan.md Workstream A3');
  }

  // TODO: focusElement(String nodeRef) — Feature 2 "Guided TalkBack
  // Assist" (intent.md §4). Relies entirely on the WebView's own
  // accessibility bridge to Android's TalkBack for the resulting
  // announcement — no separate accessibility mechanism of this
  // project's own. UNCONFIRMED on a real device pending spike A1b
  // (plan.md) — do not assume this works, and do not wire it into the
  // FSM as if it were load-bearing for Feature 1.
  Future<void> focusElement(String nodeRef) {
    throw UnimplementedError(
      'focusElement (.focus() via JS bridge) — Feature 2, pending spike A1b',
    );
  }
}
