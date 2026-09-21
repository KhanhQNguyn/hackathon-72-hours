# Milestone 12 — `dom_reader.js`: text extraction + `MutationObserver` wiring + `readDom()` completion

**One-line goal:** finish the DOM-reading pipeline with visible-text extraction and the perceive-again trigger, so the app re-reads the DOM after every action instead of planning blindly off one upfront read.

## Project context
`02-spec.md` §5: *"Perceive → act → wait-for-stable → perceive-again loop, not a single upfront read-and-plan pass... a JS `MutationObserver` (attached at `AT_DOCUMENT_START`, before the page's own scripts run) detects SPA-style in-place DOM changes, combined with the WebView's own page-load event listener to detect full page navigations. Only once the page reports stable does the next perception pass run."*

## Maps to plan.md task(s)
A2 (part 4 of 4)

## Preconditions
Milestones 09, 10, 11

## Files touched
- `assets/js/dom_reader.js` — edit
- `lib/services/webview_controller_service.dart` — edit (finish `readDom()`, add the perceive-again event stream)

## Implementation spec
- `__domReader_getVisibleText()`: returns `document.body.innerText` filtered to elements that are actually visible (`offsetParent !== null` and not `display: none`/`visibility: hidden`), truncated to **8000 characters** (large enough for a real job listing, small enough to bound OpenAI token cost per `02-spec.md` §2's "minimal context" principle) with a `truncated: boolean` flag in the return value.
- **`MutationObserver` wiring**, injected at the `UserScript`'s top level (registered at `AT_DOCUMENT_START` per `02-spec.md` §1/§5): `new MutationObserver(callback).observe(document.body, {childList: true, subtree: true, attributes: false})`, where `callback` debounces **300ms** (long enough for a batch of React re-renders to settle, short enough not to feel laggy) then posts `{"type": "dom_changed"}` back via the `WebMessageListener` channel.
- **Page-load listener (Dart side):** `InAppWebViewController`'s `onLoadStop` callback also triggers a full re-perceive.
- Add a new public stream on `WebViewControllerService`: `Stream<void> get domChangedEvents` — both the `MutationObserver` message and `onLoadStop` feed into it. This is what decides "should I re-read now" (per the perceive-act-wait-perceive loop) — callers subscribe, they never poll.
- Final `readDom()` signature: `Future<DomSnapshot> readDom()` → `DomSnapshot({images, searchCandidates, submitCandidates, labeledFields, visibleText, truncated})` — extend `DomSnapshot` accordingly (it currently only has `images`, `formFields`, `visibleText` from scaffolding).

## Definition of Done
- [ ] On the real target page, triggering a client-side DOM change (e.g. typing into a search box that shows dynamic autocomplete results) fires a `domChangedEvents` event within ~500ms
- [ ] Navigating to a new page (full reload) also fires `domChangedEvents`
- [ ] `readDom()` returns a fully-populated `DomSnapshot` combining milestones 09–12's four JS functions in one Dart call

## Size
L — if this proves too large in practice, split the `MutationObserver`/stream Dart-side plumbing into its own follow-up file, separate from the `getVisibleText()` JS function.
