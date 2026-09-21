# Milestone 01 — Spike: DOM-reading test harness

**One-line goal:** prove the JS-bridge approach can reliably read DOM content from the real target job-portal page before any production code is built on top of that assumption.

## Project context
`job_access_assist` is a Flutter/Dart Android app helping blind/low-vision job seekers search and apply for jobs by voice. It reads and acts on a real job portal (VietnamWorks) via an embedded `flutter_inappwebview` WebView + injected JavaScript, uses the OpenAI API for parsing/matching/narration, and is orchestrated by a Finite State Machine (`lib/orchestration/application_flow_fsm.dart`) that is the single source of truth for where the flow is. Full background: `01-intent.md`, `02-spec.md`, `06-plan.md`.

## Maps to plan.md task(s)
A1

## Preconditions
None — can start immediately. This is the single highest-risk validation in the whole project; do it first.

## Files touched
- `lib/services/webview_controller_service.dart` — edit (temporary spike code; replace the stub bodies of `loadTarget`/`readDom` with a minimal real implementation)
- `lib/ui/screens/spike_harness_screen.dart` — **create fresh**, a throwaway debug screen. Not part of `05-scaffolder.md`'s tree; explicitly temporary — delete it or gate it behind a debug flag once this milestone is done.
- `lib/utils/logger.dart` — edit (implement `log()` minimally, just enough to print to Logcat)

## Implementation spec
Build `spike_harness_screen.dart` with:
- A `TextField` for a URL and a "Load" button calling `InAppWebViewController.loadUrl(urlRequest: URLRequest(url: WebUri(url)))`.
- A "Read DOM" button that calls `controller.evaluateJavascript(source: script)` with an **inline** script (not the full `dom_reader.js` yet — that's milestones 09–12). The inline script should return a JSON string of this shape:
  ```json
  {
    "images": [{"src": "string", "alt": "string|null"}],
    "inputs": [{"tag": "string", "type": "string|null", "placeholder": "string|null"}],
    "textSample": "string"
  }
  ```
- Log the returned JSON via `Logger.log()`.
- Load the real target page — whatever listing the team has picked per `01-intent.md` §7 at the time this runs (VietnamWorks is the confirmed platform; the specific listing is a separate open item).

## Definition of Done
- [ ] App installs on a real Android device and loads the real target URL inside the embedded WebView
- [ ] "Read DOM" returns non-empty `images`/`inputs` arrays in Logcat, and those values visibly match what's actually on the page
- [ ] Pass/fail is explicitly recorded against `06-plan.md` A1's stated criterion: **PASS** if image `src` URLs and form-field locations are detected; **FAIL** if the page is heavily client-rendered with no stable selectors at injection time. On FAIL, stop — this is a stop-and-reassess trigger per `06-plan.md` Risks, not something to keep building on top of. Do not start milestone 09 until this is resolved PASS.

## Size
M
