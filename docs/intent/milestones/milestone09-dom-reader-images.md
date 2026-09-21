# Milestone 09 — `dom_reader.js`: image + alt-text enumeration

**One-line goal:** detect every image on the loaded page and whether it carries meaningful alt text, feeding Feature 1's image-to-speech barrier detection.

## Project context
`job_access_assist` reads the currently-loaded WebView page's DOM via injected JavaScript (`assets/js/dom_reader.js`), called from Dart through `flutter_inappwebview`'s `evaluateJavascript`. This is the first of four milestones building that script out from its current scaffolded TODO-only state. Full background: `02-spec.md` §5–§6 ("Web Content Perception").

## Maps to plan.md task(s)
A2 (part 1 of 4)

## Preconditions
Milestone 01 passed (DOM-reading spike confirmed feasible)

## Files touched
- `assets/js/dom_reader.js` — edit
- `lib/services/webview_controller_service.dart` — edit (`readDom()` stub → real implementation, calling this function)
- `lib/models/dom_snapshot.dart` — edit if needed (confirm `DomImage(src, altText)` fields are sufficient — they already are from scaffolding)

## Implementation spec
- `dom_reader.js` exposes a function `__domReader_getImages()` returning a JSON array:
  ```json
  [{ "src": "string", "alt": "string|null", "hasAlt": true }]
  ```
  `hasAlt` is `true` only if `alt` is present **and** non-empty after trimming. An `alt=""` (explicitly empty, i.e. marked decorative) image gets `hasAlt: false` **by design** — it is not a candidate for the image-to-text vision fallback, since an explicitly empty alt means "decorative," not "missing."
- `WebViewControllerService.readDom()` signature: `Future<DomSnapshot> readDom()` — calls `__domReader_getImages()` (and milestones 10/11/12's other functions once they exist) and assembles one `DomSnapshot`.

## Definition of Done
- [ ] Against a hand-authored local HTML fixture with 3 images — one with real alt text, one with `alt=""`, one with no `alt` attribute at all — `readDom().images` returns exactly 3 entries with `hasAlt` = `true, false, false` respectively
- [ ] `flutter analyze` clean

## Size
M
