# spec.md — [Product Name TBD]

*(built from intent.md — see that file for Problem/Users/Outcome/Features/Constraints)*

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| App shell (UI) | **Flutter (Dart)** | Already decided in intent.md. The app's *own* visible UI surface is intentionally small — a voice-trigger button, a live status/transcript readout, a language toggle (EN/VI). Most of the "product" happens inside the embedded WebView/PDF view, not our own screens. |
| Web content perception/action | **`webview_flutter`** (embedded in-app WebView) + **injected JavaScript** (`runJavaScriptReturningResult` / `addJavaScriptChannel`) for direct DOM access | **Architecture change from the original plan.** The original design used a native Kotlin `AccessibilityService` to read a third-party native app's UI tree. That approach has a known blind spot: content rendered inside a `WebView` doesn't reliably expose through Android's accessibility tree (confirmed via the team's own earlier real-device testing on a different app, where WebView-rendered content reported as outside the app's normal accessibility scope). Since Stage 2's targets — job portals, careers pages, web-based application forms — **are** web content, reading them via `AccessibilityService` would hit exactly this blind spot. Hosting the target page in the app's **own** embedded WebView and reading/acting on it via injected JS gives direct, first-party DOM access (`document.querySelectorAll`, `img.alt`, `getBoundingClientRect`, form field detection), sidestepping the blind spot entirely. This is the highest-risk, highest-value component; build/test it first, same as the old `AccessibilityService` was. |
| PDF perception | **Flutter PDF-parsing library** — team to confirm final choice during build (candidates: `syncfusion_flutter_pdf` for richer text/field extraction, or `pdf_text` for a lighter pure-text extraction); note in this file which one was actually picked and why, once decided | PDF application forms are not reliably readable via the WebView/DOM approach (a PDF isn't DOM content) and need their own extraction path. Whichever library is chosen, prefer one that can distinguish form fields from body text, not just dump raw text. |
| AI / NLU + vision | **OpenAI API** — `gpt-4o-mini` for intent parsing (voice command → structured request) and DOM/PDF-content filtering, summarization, and form-field matching; `gpt-4o` (vision) for **image-to-text** when a job description is posted as an image with no usable alt text (the core Stage 2 barrier) — send the extracted image, ask it to transcribe/describe the actual job-description content. | Team's choice, unchanged reasoning from before: `gpt-4o-mini` keeps per-call cost/latency low for frequent filtering/matching calls; vision is only invoked when an image lacks meaningful alt text, not on every step, to control cost and latency. Filtering/matching prompts should take the target page's DOM snapshot or PDF text as generic parameters rather than hardcoding one portal's field names, so the same logic generalizes to a second portal later without a prompt rewrite — only 1–2 real platforms are built/tested now, but the interface is written generically from the start. |
| Voice I/O | **`speech_to_text`** + **`flutter_tts`** (Flutter plugins wrapping Android `SpeechRecognizer`/`TextToSpeech`) — on-device | Unchanged from before: same underlying on-device engines, free, no network dependency. |
| Local storage | **`SharedPreferences`** (simple key-value: language setting, saved profile fields for form-fill, last search) — no real database | No user accounts, no server-side state, no multi-device sync needed for an MVP. |
| Deployment | **Debug/release APK, sideloaded** | No Play Store (review timelines don't fit 72h). No hosting/infra needed since there's no backend. |
| Supporting tools | AI coding assistant (Claude Code) for implementation velocity on the WebView/JS-bridge integration, PDF parsing, and prompt engineering; Git for version control, following the team's intent → spec → scaffolder → plan flow | Per intent.md's engineering-approach note: coding speed buys reliability on the 1–2 supported real targets, not broader scope. |

**No custom backend for the MVP.** The Flutter app calls the OpenAI API directly over HTTPS from the device. This is a deliberate scope cut, not an oversight — see the Security note in Section 3 for the trade-off this creates and how to phrase it safely in the deck. Unchanged reasoning from the original plan.

## 2. API

- **This project has no API it hosts** — there's no server, so no REST/GraphQL surface to design or version. "API" here means **how the app calls out** to OpenAI's REST API (`chat/completions`, both text and vision-capable calls).
- **Call pattern:** synchronous request/response per step (e.g., one call to parse the voice command into a request intent; one call per page/PDF to filter/summarize content or match form fields; occasional vision calls only when an image lacks usable alt text). Each call should carry minimal context (the relevant DOM subset/PDF text/image, not the whole page or file) to control latency and token cost.
- **Roadmap (not built now):** if this became a real product, a thin backend would proxy these calls so the API key isn't shipped in the client — see Section 3.

## 3. Middleware

- No server middleware exists (no server). The on-device equivalents:
  - **Error/timeout handling around every WebView/JS action and PDF parse** — if an injected script doesn't return the expected result, a page doesn't finish loading, or PDF parsing throws, treat it as a recoverable failure: narrate ("that didn't load as expected, retrying...") and retry once or twice before giving up and asking the user for guidance. Same "built-in robustness" principle from intent.md's Success Criteria, retargeted to the new failure modes (page-load failure, unexpected DOM structure, PDF parse failure, form field not found) instead of the old ad-popup/action-timeout modes.
  - **Local logging** (Logcat + a lightweight in-app event log) for debugging during the build, not a production observability stack.
  - **OpenAI rate limits:** be aware of per-minute request/token limits on whichever tier the team is on; the filtering/matching call happens frequently (every page/PDF), so a burst of retries during error recovery could hit limits — worth a simple backoff, not a queueing system.
- **⚠️ Security note, flag this to the team explicitly:** shipping the OpenAI API key inside the client APK is insecure (anyone who decompiles the APK can extract it and rack up charges on your account). This is a known, deliberate shortcut for a 72-hour hackathon prototype — not something to ship as a real product. Mitigate minimally: keep the key out of the Git repo (use a local `local.properties`/`.env` excluded via `.gitignore`, injected at build time), and mention "backend key-proxy" as roadmap/future-work in the deck rather than pretending this is production-secure. Unchanged from the original plan.

## 4. Authentication

- **This app has no authentication of its own.** There are no user accounts, no login screen. If the target job portal requires the user to be signed in (e.g. to view or submit an application), the user signs into that site themselves inside the app's embedded WebView, the same way they would in any browser — our app never touches those credentials directly; it only reads/acts on whatever page is already loaded in the WebView it hosts.
- WCAG 2.2 SC 3.3.8 (Accessible Authentication) therefore doesn't directly apply to this MVP's own flow, since we implement no auth flow ourselves. **If the roadmap ever adds accounts** (e.g., to save a reusable application profile across multiple job applications), that future auth flow must avoid CAPTCHA-only or memory/puzzle-based verification, per SC 3.3.8 — worth a one-line roadmap note in the deck, not something to build now.

## 5. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  User (blind/low-vision)                                     │
│  speaks a command → hears narration/confirmations             │
└───────────────┬────────────────────────────────────────────┘
                │ voice in/out
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Flutter app shell (Dart)                                     │
│  - Android SpeechRecognizer (STT) / TextToSpeech (TTS)        │
│  - Minimal UI: trigger button, status readout, language toggle│
│  - Must itself be fully accessible (Semantics widgets) —      │
│    see Section 7                                              │
└───────────────┬───────────────────────────┬──────────────────┘
                │ Platform Channel           │ HTTPS
                ▼                            ▼
┌───────────────────────────────┐  ┌──────────────────────────┐
│ Embedded WebView               │  │ OpenAI API                │
│ (webview_flutter, hosts the    │  │ - gpt-4o-mini: intent      │
│ real job portal/careers page)  │  │   parsing, DOM/PDF-content │
│ - injected JS reads the DOM    │◄─┤   filtering, form-field    │
│   (images, form fields, text)  │  │   matching                 │
│ - injected JS fills form fields│  │ - gpt-4o (vision):         │
│   + dispatches input events    │  │   image-to-text for job    │
└───────────────┬─────────────────┘  │   descriptions posted as  │
                │                     │   images with no alt text │
                │                     └──────────────┬────────────┘
                │                                    │
┌───────────────▼─────────────────┐                  │
│ PDF-parsing service (Dart)       │──────────────────┘
│ (extracts text/fields from a     │
│ downloaded application-form PDF) │
└───────────────────────────────────┘
```

- **Why this architecture fits a 3-day build:** still client-only — no server to stand up, deploy, or keep alive during the demo/evaluation window. The two genuinely hard components (the WebView/JS-bridge DOM reader and the AI filtering/matching/vision layer) are isolated behind clear boundaries, so they can be built and tested somewhat independently by different team members in parallel — same parallelization benefit as the original architecture.
- **Single points of failure to test early:** the WebView + JS-bridge round trip itself (can injected JS reliably read and act on a real page's DOM) and the PDF-parsing library's ability to extract structure from a real application form — both are exactly what the spike (still pending, see plan.md) needs to validate before the rest of the build depends on them.

### Software architecture pattern: layered + Finite State Machine (FSM)

Classic web patterns (N-Tier, modular monolith) describe how a *server* is organized — this project has no server, so they don't map directly. What's used instead, unchanged from the original plan:

- **Orchestration core = a Finite State Machine**, not a loose collection of feature code: `Idle → Listening → ParsingIntent → LoadingTarget → ReadingContent → AwaitingUserAction → FillingForm → AwaitingSubmitConfirmation → Done`, with `Error/Retrying` transitions back to the state that failed. Modeling it explicitly as an FSM gives a single source of truth for "where the flow is," makes retry logic a normal state transition rather than special-cased code, and makes the flow unit-testable without a live phone/mic/network.
- **Layers around the FSM** (mirrors the bounded contexts in Section 6):
  1. **UI** — Flutter widgets, purely presentational, driven by current FSM state (effectively MVVM, with the FSM as the "ViewModel")
  2. **Orchestration** — the FSM itself, pure Dart, no platform/network code inside it
  3. **Services** — thin, swappable wrapper classes per external dependency (`SpeechService`, `OpenAIService`, `WebViewControllerService`, `PdfReaderService`) — mockable, so UI work can proceed in parallel with the real WebView/PDF integration still being built
  4. **Web content** — the embedded WebView, driven only via the JS-bridge service, no business logic inside the injected script beyond DOM extraction/manipulation itself
- **Deliberately not using:** full Clean Architecture (entities/use-cases/repositories/DI ceremony). Right call for production, not worth the setup cost for 3 people/72 hours — unchanged reasoning from before.

## 6. Domain

Bounded contexts / responsibilities, mapped to Core Features in intent.md:

1. **Voice Command Intake** — on-device `SpeechRecognizer` (STT), silence/end-of-speech detection, handoff of transcript to the NLU call. Same distortion-mitigation chain as the original plan: pin STT locale explicitly per session (`vi-VN`/`en-US`), use constrained command phrasing, check confidence score before forwarding to the LLM, pass the n-best hypothesis list downstream.
2. **Intent Parsing** — OpenAI (`gpt-4o-mini`, text-only) call that turns the transcript into a structured request (e.g. "read this job listing," "fill and submit this application"). *(supports all 4 Features)*
3. **Web Content Perception** *(was "Screen Perception")* — injected JS reads the currently-loaded WebView page's DOM: detects images (and whether they carry meaningful `alt` text), detects form fields (`<input>`/`<select>`/`<textarea>` plus associated labels), and extracts visible text content. *(Feature 2, barrier #1)*
4. **PDF Perception** *(new)* — the PDF-parsing service extracts text and, where possible, distinguishes form-field structure from body text out of a downloaded application-form PDF. *(Feature 3, barrier #2)*
5. **AI Filtering & Matching** — suppresses navigation/ad/irrelevant DOM content, summarizes/narrates the actual job-listing content, runs the vision fallback on images lacking alt text, and matches parsed user-provided information (name, phone, etc.) to detected form fields. *(Features 1 & 2, barriers #1, #3, #4)*
6. **Confirmation Manager** — the hard-stop checkpoint before final submission: pauses the flow, reads the fully-filled-in application form back in full, and waits for explicit user confirmation before continuing. *(Feature 4, retargeted from the old "before payment" checkpoint to "before submit")*
7. **Form-Fill Orchestrator** *(was "Action Orchestrator")* — drives the actual form-field-filling (`element.value = ...` + dispatching an `input` event) via the JS bridge once confirmed information is available; narrates every step in between (not just at the checkpoint). *(Feature 4)*
8. **Error Recovery** — timeout/retry/narrate-and-recover wrapper around web/PDF actions, handling the new failure modes: page fails to load in the WebView, PDF fails to parse, or an expected form field isn't found. *(Success Criteria's "built-in robustness" principle, same idea as before, new failure modes)*

## 7. Design Requirements — WCAG 2.2 AA, mapped to Android/Flutter

WCAG 2.2 is technically a *web content* standard, so it doesn't apply verbatim to a native Android app — but its principles map cleanly, and this table exists so the team can honestly say in the deck "we designed against WCAG 2.2 AA from the architecture up," backed by a real mapping rather than a claim. Unchanged from the original plan — this table applies to **our own app's UI**, not to the third-party portals/PDFs we read (which we can only perceive/compensate for, not redesign).

| WCAG 2.2 AA criterion | Android/Flutter equivalent | How this project implements it |
|---|---|---|
| **1.4.3 Contrast (Minimum)** — 4.5:1 text, 3:1 large text | Flutter theme color tokens checked against contrast ratio | Define the app's color palette with contrast-checked pairs from the start; matters mainly for low-vision users and sighted teammates testing the app |
| **1.4.11 Non-text Contrast** — 3:1 for UI components/icons | Same, applied to buttons/icons/focus indicators | Trigger button and status icons meet 3:1 against background |
| **1.4.4 Resize Text** — up to 200% without loss of function | Flutter's `MediaQuery.textScaleFactor` / respecting system font size | Use scalable text units, not fixed pixel sizes that break layout when the OS font-size setting is increased |
| **1.4.1 Use of Color** — don't convey info by color alone | N/A mostly (voice-first UI) | Status conveyed via narration (TTS) + text label, never color alone, for the rare visual state (e.g. a colored status dot) |
| **2.5.8 Target Size (Minimum)** — 24×24 CSS px minimum | Android Material Design guideline is 48dp minimum, which already exceeds the WCAG floor | Use standard Material button sizing (48dp+) for the trigger button and any tappable elements |
| **2.4.7 Focus Visible / 2.4.11 Focus Not Obscured** | TalkBack's focus highlight, driven by proper widget semantics | Ensure every interactive Flutter widget has a `Semantics` label and is reachable in a logical TalkBack traversal order — test with TalkBack on, not just by looking at the screen |
| **2.1.1 Keyboard (all functionality without a mouse)** | Android equivalent: full functionality operable via TalkBack gestures / external switch access | Since the whole point of the app is voice-first operation, largely satisfied by design — verify the minimal touch UI (trigger button) is also fully operable via TalkBack swipe-navigation |
| **3.3.2 Labels or Instructions** | `Semantics(label: ...)` on every interactive widget | Trigger button, language toggle, and any settings must have clear, descriptive accessibility labels |
| **3.3.1 Error Identification** | TTS narration of errors, not silent failure or visual-only error text | When Error Recovery hits a recoverable error (Section 3), the error is **spoken**, not just logged or shown as text the user can't see |
| **4.1.2 Name, Role, Value** | Correct Flutter `Semantics`/widget types | Avoid "div-soup" equivalent in Flutter — don't build custom-painted widgets with no semantic role when a standard accessible widget exists |
| **3.3.8 Accessible Authentication** | N/A for MVP (no auth flow of our own — see Section 4) | Documented as roadmap-only consideration if a saved-profile/account feature is ever added |

**Testing method, not just design:** before the demo recording, run the app's own UI with **TalkBack enabled** and confirm it's fully navigable — cheapest, highest-credibility accessibility validation step available, and directly demonstrates "we practice what we preach" to judges.

### Items from accessibility-wcag.md not yet covered above, closed here

Unchanged from the original plan — these cross-checks still apply as-is:

| Checklist item (as written, web-oriented) | Android/Flutter equivalent | Where it's implemented |
|---|---|---|
| `<html lang="...">` declared | Flutter `MaterialApp(locale: ...)` set from the language preference, not left to device default | `preferences_service.dart` drives this — same source of truth as the STT/TTS locale (spec.md §6.1) |
| Images have meaningful alt text; decorative images get `alt=""` | `Semantics(label: ...)` for meaningful icons in **our own** UI; `ExcludeSemantics` or `Semantics(label: '')` for purely decorative ones | Audit the app's own minimal icon set explicitly. (Note: images **inside the target job portal/PDF** without alt text are handled by Feature 1's vision fallback, a functional feature, not a WCAG-compliance checklist item for our own UI.) |
| Error messages announced to screen readers (`aria-live`/`aria-describedby`) | `Semantics(liveRegion: true)` on the status/narration text widget | `status_narration_view.dart` (scaffolder.md) should be a live region — if TTS narration fails or is muted, TalkBack still announces status text changes automatically |
| Drag-and-drop needs a click/tap alternative | N/A | No drag interactions exist anywhere in this app's own UI |
| Automated accessibility scan tool (axe/Lighthouse are web-only) | **Android equivalent: Google's Accessibility Scanner app**, run against the built APK | Supplement to manual TalkBack testing — same "~30-40% coverage, doesn't replace manual testing" caveat applies |
| Video/audio has captions or a transcript | Applies to the **submission video itself** | Add burned-in or SRT captions to the demo video |

## 8. Local State (schema.md skipped — see decision below)

No `schema.md`/`models.md` file — there's no database, so there are no models/relationships to document. This project qualifies (zero models). The only persisted state, documented here instead of in a separate file:

| Key | Type | Notes |
|---|---|---|
| `language_pref` | string (`en` \| `vi`) | Drives STT locale + TTS voice + UI text |
| `applicant_profile` | map, optional | Reusable form-fill fields (name, phone, email, etc.) the user provides once and confirms before each submission — convenience only, not required for MVP functionality |
| `last_search_query` | string, optional | Convenience only |

Stored via Flutter `SharedPreferences`. No user accounts, no server-side persistence, nothing else to model.

---

## ⚠️ To fill in as the build progresses

- [x] endpoints.md — **not needed**, confirmed. No backend, so no hosted routes to document. The project's one outbound API call (to OpenAI) is documented in Section 2 above.
- [ ] Confirm OpenAI API tier/rate limits and whether the hackathon provides any API credits
- [ ] Run the WebView + JS-bridge spike against a real job portal/careers page (still pending, highest-risk unknown — see intent.md, plan.md)
- [ ] Pick and confirm the PDF-parsing library (`syncfusion_flutter_pdf` vs. `pdf_text` vs. other) once tested against a real application-form PDF; update Section 1's table with the final choice and why
- [x] schema.md/endpoints.md — **not needed**, confirmed. No backend, no database.
- [ ] TalkBack pass on the app's own UI before final demo recording
