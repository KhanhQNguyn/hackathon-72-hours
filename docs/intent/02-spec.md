# spec.md — [Product Name TBD]

*(built from intent.md — see that file for Problem/Users/Outcome/Features/Constraints)*

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| App shell (UI) | **Flutter (Dart)** | Already decided in intent.md. The app's *own* visible UI surface is intentionally small — a voice-trigger button, a live status/transcript readout, a language toggle (EN/VI). Most of the "product" happens inside the embedded WebView/PDF view, not our own screens. |
| Web content perception/action | **`flutter_inappwebview`** (embedded in-app WebView) + **injected JavaScript** (`UserScript`, `WebMessageListener`) for direct DOM access — **switched from `webview_flutter`, see Reason** | **Architecture change from the original plan, refined further after research.** The original design used a native Kotlin `AccessibilityService` to read a third-party native app's UI tree; that has a known blind spot on WebView-rendered content (confirmed via the team's own earlier real-device testing), so the design moved to hosting the target page in the app's own embedded WebView with injected JS for direct DOM access. **Library choice finalized:** since the target content is a **real, uncontrolled third-party site (VietnamWorks)**, `webview_flutter`'s `addJavaScriptChannel` cannot verify which script on the page triggered a message — any third-party ad/tracker script embedded in the real site could, in principle, call into it, a real concern when embedding untrusted content. `flutter_inappwebview`'s `WebMessageListener` can restrict which origins may send messages, and its `UserScript` with `AT_DOCUMENT_START` injection timing is a better fit for attaching a `MutationObserver` before the page's own scripts run (see Section 5's perceive-act-wait-perceive note). This is the highest-risk, highest-value component; build/test it first. |
| PDF perception | **`syncfusion_flutter_pdf`** — **confirmed choice**, no longer a candidate alongside `pdf_text` | Has a free community license tier suitable for a small team, and richer text/field extraction than a pure-text-only alternative. PDF application forms aren't reliably readable via the WebView/DOM approach (a PDF isn't DOM content) and need their own extraction path; preferring a library that can distinguish form fields from body text, not just dump raw text, is why this was chosen over a lighter pure-text extractor. |
| OCR fallback | **`google_mlkit_text_recognition`** | Triggered when the PDF parser finds no extractable text layer — i.e. the application-form PDF is actually a scanned image, not a real text-layer PDF. On-device, free, no added API cost/latency vs. routing every scanned PDF through the vision API. This is the same underlying accessibility problem the whole project addresses (inaccessible content with no text alternative), showing up inside the tool's own input pipeline. |
| PDF-page rasterization (for OCR) | **`pdfx`** — resolved during milestone20 implementation | `google_mlkit_text_recognition` takes an image, not a PDF page, so something has to render the page to an image first. The originally-recommended default (render via `flutter_inappwebview`'s WebView + a screenshot) turned out to need a live widget/`BuildContext` to host an off-screen WebView, which `PdfReaderService` — a plain service class like the rest of the service layer — doesn't have; it can't be made to work without either giving that service a widget dependency it otherwise has no reason for, or restructuring the call to come from a widget instead. `pdfx` renders headlessly from a plain Dart call, matching the service's existing shape, at the cost of a third PDF-handling dependency alongside `syncfusion_flutter_pdf`. |
| Native file picker | **`file_picker`** | Browsers block scripts from programmatically assigning a file to `<input type="file">` for security reasons — this is not a bug to work around via JS injection, it needs a native file-picker invoked instead, handing the selected file (e.g. a CV attachment) back into the flow. |
| AI / NLU + vision | **OpenAI API** — `gpt-4o-mini` for intent parsing (voice command → structured request) and DOM/PDF-content filtering, summarization, and form-field matching; `gpt-4o` (vision) for **image-to-text** when a job description is posted as an image with no usable alt text (the core Stage 2 barrier) — send the extracted image, ask it to transcribe/describe the actual job-description content. | Team's choice, unchanged reasoning from before: `gpt-4o-mini` keeps per-call cost/latency low for frequent filtering/matching calls; vision is only invoked when an image lacks meaningful alt text, not on every step, to control cost and latency. Filtering/matching prompts should take the target page's DOM snapshot or PDF text as generic parameters rather than hardcoding VietnamWorks-specific field names, so the same logic generalizes to a second portal later without a prompt rewrite — only VietnamWorks is built/tested now, but the interface is written generically from the start. |
| Voice I/O | **`speech_to_text`** + **`flutter_tts`** (Flutter plugins wrapping Android `SpeechRecognizer`/`TextToSpeech`) — on-device | Unchanged from before: same underlying on-device engines, free, no network dependency. |
| Local storage | **Three mechanisms for three different needs, not one catch-all:** (1) **`sqflite`** for the structured applicant profile (name, phone, email, CV file path); (2) **`flutter_secure_storage`** specifically for sensitive PII fields within that profile (email, phone); (3) **`SharedPreferences`** for simple settings only (language preference, last search) | **Upgraded from plain `SharedPreferences` for everything.** Multi-field structured data (the applicant profile) doesn't suit a flat key-value store well — `sqflite` gives it real structure. Sensitive PII fields within that profile get the added protection of `flutter_secure_storage` specifically, rather than sitting in a plain SQLite file. `SharedPreferences` remains the right, simplest tool for settings that were never sensitive or structured to begin with — this is a targeted upgrade for the profile data, not a wholesale replacement. |
| Deployment | **Debug/release APK, sideloaded** | No Play Store (review timelines don't fit 72h). No hosting/infra needed since there's no backend. |
| Supporting tools | AI coding assistant (Claude Code) for implementation velocity on the WebView/JS-bridge integration, PDF parsing, and prompt engineering; Git for version control, following the team's intent → spec → scaffolder → plan flow | Per intent.md's engineering-approach note: coding speed buys reliability on the one confirmed real target (VietnamWorks), not broader scope. |

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
│ (flutter_inappwebview, hosts   │  │ - gpt-4o-mini: intent      │
│ the real VietnamWorks page)    │  │   parsing, DOM/PDF-content │
│ - UserScript (AT_DOCUMENT_START)│◄─┤   filtering, form-field    │
│   reads the DOM (images, form  │  │   matching                 │
│   fields, text) via a          │  │ - gpt-4o (vision):         │
│   MutationObserver              │  │   image-to-text for job    │
│ - WebMessageListener (origin-  │  │   descriptions posted as  │
│   restricted) fills form fields│  │   images with no alt text │
│   + dispatches input events    │  └──────────────┬────────────┘
│ - focusElement(nodeRef) for     │                 │
│   Feature 2 (Guided TalkBack)  │                 │
└───────────────┬─────────────────┘                 │
                │                                    │
┌───────────────▼─────────────────┐                  │
│ PDF-parsing service (Dart)       │──────────────────┘
│ (syncfusion_flutter_pdf; falls   │
│ back to google_mlkit_text_       │
│ recognition OCR if no text layer)│
└───────────────────────────────────┘

┌─────────────────────────────────┐
│ file_picker (native)             │  ← invoked for CV upload; JS
│ hands the selected file back      │    cannot set <input type="file">
│ into the flow                    │    for security reasons
└─────────────────────────────────┘
```

- **Why this architecture fits a 3-day build:** still client-only — no server to stand up, deploy, or keep alive during the demo/evaluation window. The two genuinely hard components (the WebView/JS-bridge DOM reader and the AI filtering/matching/vision layer) are isolated behind clear boundaries, so they can be built and tested somewhat independently by different team members in parallel — same parallelization benefit as the original architecture.
- **Single points of failure to test early:** the WebView + JS-bridge round trip itself (can injected JS reliably read and act on a real page's DOM) and the PDF-parsing library's ability to extract structure from a real application form — both are exactly what the spike (still pending, see plan.md) needs to validate before the rest of the build depends on them.

### Software architecture pattern: layered + Finite State Machine (FSM)

Classic web patterns (N-Tier, modular monolith) describe how a *server* is organized — this project has no server, so they don't map directly. What's used instead, unchanged from the original plan:

- **Orchestration core = a Finite State Machine**, not a loose collection of feature code. **Updated state list** (field-by-field form-fill loop and edit-a-field capability, added on top of the pivot): `Idle → Listening → ParsingIntent → LoadingTarget → ReadingContent → AwaitingUserAction → FillingForm(perFieldConfirmLoop) → FinalReview → [EditingField(fieldId) → FinalReview]* → AwaitingSubmitConfirmation → Done`, with `Error/Retrying` transitions back to the state that failed. `EditingField(fieldId)` can be entered from `FinalReview` any number of times before submit — a loop-back, not a full restart. `FillingForm`'s per-field loop means each field is announced, a saved-profile value offered or a new one requested, and confirmed, before advancing to the next field — the FSM does not move to `FinalReview` until every field has been individually confirmed. Modeling this explicitly as an FSM gives a single source of truth for "where the flow is," makes retry logic a normal state transition rather than special-cased code, and makes the flow unit-testable without a live phone/mic/network.
- **Checkpoints are enforced as FSM hard-states that gate the real side-effecting action, not left to the AI's own output text.** The code path that performs an actual side effect — clicking the real submit button, confirming the listing selection, resuming after a CAPTCHA — must check the FSM's current state (e.g. `fsm.state is AwaitingSubmitConfirmationState`) before it is allowed to fire, regardless of what the AI's own response text claims about user intent. An LLM narrating "the user confirmed, proceeding" is not, by itself, sufficient to trigger a submit — only an explicit `SubmitConfirmed` event transitioning the FSM out of that state is. This applies to all three checkpoints (§6 "Confirmation Manager" below), not just the submit one; it's what makes them real hard-stops rather than a convention the AI could ignore, misread, or hallucinate past.
- **Feature 2 ("Guided TalkBack Assist") reuses the same components as Feature 1** — no new architecture. It adds one JS-bridge call, `focusElement(nodeRef)`, triggered by the AI on user request within the same WebView session; the resulting TalkBack announcement relies entirely on the WebView's own OS-level accessibility bridge to Chromium/TalkBack, not on any separate mechanism this project builds. **This specific mechanism (`.focus()` reliably triggering a real TalkBack announcement) is unconfirmed pending its own spike** — see plan.md task A1b, run independently of Feature 1's DOM-reading spike (A1).
- **Perceive → act → wait-for-stable → perceive-again loop, not a single upfront read-and-plan pass.** The AI can only perceive what's currently rendered — hidden menus, unopened tabs, and not-yet-loaded content are invisible until triggered, and this is true on both SPA and traditional multi-page sites. Rather than reading the whole DOM once and planning the entire action sequence upfront, the app re-reads after every action: a JS `MutationObserver` (attached at `AT_DOCUMENT_START`, before the page's own scripts run) detects SPA-style in-place DOM changes, combined with the WebView's own page-load event listener to detect full page navigations. Only once the page reports stable does the next perception pass run.
- **Heuristic pre-filtering before AI selection, not a raw DOM/HTML dump to the AI.** When identifying which detected element is a search bar, a submit button, or a specific labeled form field, the injected JS first narrows candidates using cheap attribute/DOM heuristics — `type="search"`, `role="search"`/`role="button"`, and keyword matching against `placeholder`/`aria-label`/`name` for search fields; equivalent labeled-element heuristics for submit buttons and specific form fields. Only that short, structured candidate list — not the raw page DOM/HTML — is sent to the AI for final ranking/selection (feeding the element-selection confidence check in §6 "AI Filtering & Matching" below). This matters for both cost/latency (a full page DOM can be large; a short candidate list is cheap to send on every perception pass) and reliability (ranking a handful of pre-narrowed, heuristically-plausible candidates is a much stronger signal than asking the AI to locate elements cold from a full raw dump on an unfamiliar page).
- **Verify-after-action, not trust-the-call-returned.** After the JS bridge fills a form field (or performs any DOM-mutating action), the same field/element is re-read to confirm the mutation actually took effect before the flow treats it as successful — a JS call returning without error does not guarantee the value stuck (e.g. a React/Vue-controlled input can silently reset a programmatically-set value on its next re-render). See §6 "Form-Fill Orchestrator" below.
- **Layers around the FSM** (mirrors the bounded contexts in Section 6):
  1. **UI** — Flutter widgets, purely presentational, driven by current FSM state (effectively MVVM, with the FSM as the "ViewModel")
  2. **Orchestration** — the FSM itself, pure Dart, no platform/network code inside it
  3. **Services** — thin, swappable wrapper classes per external dependency (`SpeechService`, `OpenAIService`, `WebViewControllerService`, `PdfReaderService`, `OcrService`, `FilePickerService`, `ApplicantProfileService`) — mockable, so UI work can proceed in parallel with the real WebView/PDF integration still being built
  4. **Web content** — the embedded WebView, driven only via the JS-bridge service, no business logic inside the injected script beyond DOM extraction/manipulation itself
- **Deliberately not using:** full Clean Architecture (entities/use-cases/repositories/DI ceremony). Right call for production, not worth the setup cost for 3 people/72 hours — unchanged reasoning from before.

## 6. Domain

Bounded contexts / responsibilities, mapped to Core Features in intent.md:

*(Note on numbering: "Feature 1 part N" below refers to the four numbered items under Feature 1 — "AI Auto-Pilot" — in intent.md §4; "Feature 2" refers to the separate "Guided TalkBack Assist" feature, not a part of Feature 1.)*

1. **Voice Command Intake** — on-device `SpeechRecognizer` (STT), silence/end-of-speech detection, handoff of transcript to the NLU call. Same distortion-mitigation chain as the original plan: pin STT locale explicitly per session (`vi-VN`/`en-US`), use constrained command phrasing, check confidence score before forwarding to the LLM, pass the n-best hypothesis list downstream.
2. **Intent Parsing** — OpenAI (`gpt-4o-mini`, text-only) call that turns the transcript into a structured request (e.g. "read this job listing," "fill and submit this application," or Feature 2's "take me to X"). *(supports all of Feature 1's parts, plus Feature 2)*
3. **Web Content Perception** *(was "Screen Perception")* — injected JS reads the currently-loaded WebView page's DOM: detects images (and whether they carry meaningful `alt` text), **heuristically narrows form fields/buttons to a short candidate list** (`type`/`role`/`placeholder`/`aria-label`/`name` keyword matching — see §5 "Heuristic pre-filtering before AI selection") rather than handing every matching element to the AI uncategorized, and extracts visible text content. *(Feature 1 part 2, barrier #1; also the DOM basis Guided Navigation/Feature 2 resolves targets against)*
4. **PDF Perception** *(new)* — the PDF-parsing service extracts text and, where possible, distinguishes form-field structure from body text out of a downloaded application-form PDF. *(Feature 1 part 3, barrier #2)*
5. **AI Filtering & Matching** — suppresses navigation/ad/irrelevant DOM content, summarizes/narrates the actual job-listing content, runs the vision fallback on images lacking alt text, and matches parsed user-provided information (name, phone, etc.) to detected form fields. **Element-selection confidence threshold — a separate mechanism from STT confidence (§6.1 above):** when deciding which detected element (search bar, submit button, a specific labeled field) is the right one to act on, the AI's confidence in that match is checked against an agreed threshold (starting value to tune empirically, same pattern as the STT threshold in spec.md §6.1/plan.md B3). Below it, the flow does **not** silently proceed with the top guess — it narrates the ambiguity (e.g. "I see two fields that could be the search box — one labeled 'Từ khóa', one labeled 'Vị trí' — which one did you mean?") and asks the user to disambiguate. Same "don't guess when uncertain" principle already applied to voice input, now applied to element selection too. *(Feature 1 parts 1 & 2, barriers #1, #3, #4)*
6. **Confirmation Manager** — now backs **three** checkpoints, not one: (1) selecting a company/listing, (2) confirming before final submission at `FinalReview` — a lighter confirmation than before, since it's backed by the field-by-field loop rather than a first-time full readback — and (3) a CAPTCHA encounter, where it tries the CAPTCHA's own accessible audio-challenge option first, and otherwise narrates and hands control to the user pending a "continue" command. *(Feature 1 part 4, checkpoints 2 & 3; checkpoint 1 spans Feature 1 parts 1–2)*
7. **Form-Fill Orchestrator** *(was "Action Orchestrator")* — **redesigned as a field-by-field confirm loop, not a single fill-everything pass**: for each detected field, announces it, offers a saved applicant-profile value or requests a new one, confirms, then advances (`element.value = ...` + dispatching an `input` event via the JS bridge, **then re-reading that same field to confirm the value actually took effect before treating the fill as successful** — see §5 "Verify-after-action" above; the JS call returning without error is not proof the mutation stuck) — only once every field is confirmed does it hand off to the Confirmation Manager's `FinalReview`. Also owns the `EditingField(fieldId)` loop-back: re-collecting and re-confirming a single field on request, without restarting the whole form. Narrates every step throughout, not just at checkpoints. *(Feature 1 part 4)*
8. **Guided Navigation** *(new — Feature 2)* — on user request, resolves a named target ("the search bar") to a DOM node already exposed by Web Content Perception, and calls `focusElement(nodeRef)` via the JS bridge. Relies entirely on the WebView's own accessibility bridge to Android's TalkBack for the resulting announcement — no separate accessibility mechanism of its own. *(Feature 2 — should-have, built only after Feature 1 works, mechanism unconfirmed pending spike A1b)*
9. **Error Recovery** — timeout/retry/narrate-and-recover wrapper around web/PDF actions, handling the failure modes: page fails to load in the WebView, PDF fails to parse (including the scanned-image case routed to OCR), an expected form field isn't found, or a CV file-upload interaction is needed (routed to the native file picker, not JS injection). *(Success Criteria's "built-in robustness" principle, same idea as before, new failure modes)*

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

No `schema.md`/`models.md` file in the traditional sense — there's no backend/server-side database. There *is* now a small on-device structured store (`sqflite`), documented here instead of in a separate schema file since it's this simple:

| Key / Table | Storage mechanism | Type | Notes |
|---|---|---|---|
| `language_pref` | `SharedPreferences` | string (`en` \| `vi`) | Drives STT locale + TTS voice + UI text — simple setting, no structure needed |
| `last_search_query` | `SharedPreferences` | string, optional | Convenience only |
| `applicant_profile` (table) | `sqflite` | row: name, phone, email, cv_file_path | Reusable form-fill fields the user provides once and confirms/edits per application — **upgraded from a flat `SharedPreferences` map** because multi-field structured data doesn't suit a flat key-value store well |
| `email`, `phone` (within `applicant_profile`) | `flutter_secure_storage` | string | Sensitive PII fields get the added protection of secure storage specifically, rather than sitting in the plain `sqflite` file alongside non-sensitive fields |

No user accounts, no server-side persistence, nothing else to model. This is a targeted three-way split by sensitivity/structure need, not three redundant stores for the same data.

---

## ⚠️ To fill in as the build progresses

- [x] endpoints.md — **not needed**, confirmed. No backend, so no hosted routes to document. The project's one outbound API call (to OpenAI) is documented in Section 2 above.
- [ ] Confirm OpenAI API tier/rate limits and whether the hackathon provides any API credits
- [ ] Run the WebView + JS-bridge spike (A1) against the real VietnamWorks target (still pending, highest-risk unknown — see intent.md, plan.md)
- [ ] **New, separate spike (A1b):** confirm `.focus()` triggered via JS injection actually produces a real TalkBack announcement on a real device — load-bearing for Feature 2 only, independent of A1
- [x] PDF-parsing library — **confirmed**: `syncfusion_flutter_pdf` (Section 1)
- [x] schema.md/endpoints.md — **not needed**, confirmed. No backend; the only structured local data is the `sqflite` applicant-profile table documented in Section 8.
- [ ] TalkBack pass on the app's own UI before final demo recording
- [x] **File chooser mechanism — resolved (audit 2026-09-22):** in `flutter_inappwebview` 6.1.5 / `_android` 1.1.3 the chooser is native (`InAppWebViewChromeClient.onShowFileChooser`) with **no Dart hook**; `triggerFileChooser()` (JS `click()`) is the whole integration, and the flow announces it first and verifies the attached file afterwards. Milestone 21's "wire `onShowFileChooser`" note was wrong and is corrected there. Still needs a device: whether a scripted click satisfies the WebView's user-activation requirement
- [x] **Platform support table — recorded (audit 1.1):** `sqflite` and `flutter_inappwebview`'s `WebMessageListener` are Android(/iOS/macOS)-only; this is an Android-first build and the app now says so at startup on other platforms
- [ ] AI prompts (milestones 36–40) verified only against a scripted HTTP client — needs a live API key
- [ ] Mic cues and states (`VoiceCommandGate.onListeningChanged`, `VoiceTriggerButton`) verified in widget tests only — needs a device to judge audibility
