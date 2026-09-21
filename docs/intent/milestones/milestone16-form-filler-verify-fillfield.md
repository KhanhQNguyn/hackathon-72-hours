# Milestone 16 — `form_filler.js` verify-after-action + `fillField()` Dart integration

**One-line goal:** after setting a field's value, re-read it to confirm the mutation actually took effect — and wire the whole thing into a Dart-callable `WebViewControllerService.fillField()`.

## Project context
`02-spec.md` §5: *"Verify-after-action, not trust-the-call-returned... a JS call returning without error does not guarantee the value stuck (e.g. a React/Vue-controlled input can silently reset a programmatically-set value on its next re-render)."* Milestone 15 built the set-value mechanism; this milestone adds the verification and the Dart-side entry point.

## Maps to plan.md task(s)
A3 (part 2 of 3)

## Preconditions
Milestone 15

## Files touched
- `assets/js/form_filler.js` — edit
- `lib/services/webview_controller_service.dart` — edit (`fillField()` stub → real implementation)

## Implementation spec
- After milestone 15's `setValue` dispatches its events, wait one animation frame (`requestAnimationFrame`), then re-read `element.value` and compare (string equality) against what was set. Return `{"success": true}` only if they match; otherwise `{"success": false, "reason": "value_did_not_stick"}`.
- `WebViewControllerService.fillField(String nodeId, String value)` signature: `Future<FillFieldResult> fillField(String nodeId, String value)`. Add `FillFieldResult` — either a small addition to `lib/models/dom_snapshot.dart` or a new `lib/models/fill_field_result.dart`: `{bool success, String? failureReason}`.
- **On `node_stale`:** `fillField` internally calls `readDom()` once (re-tagging elements with fresh `data-app-node-id`s) and retries the fill exactly once before giving up — per `02-spec.md` §3's "retry once or twice" pattern. Do not retry indefinitely.

## Definition of Done
- [ ] `fillField` against milestone 15's negative-control fixture returns `success: false, failureReason: "value_did_not_stick"` when the native-setter fix is temporarily disabled (regression guard), and `success: true` when it's enabled
- [ ] `fillField` against a node whose `data-app-node-id` was removed by a simulated re-render triggers exactly one internal `readDom()` retry — verify via a call counter on a test double, not just "it eventually succeeded"

## Size
M
