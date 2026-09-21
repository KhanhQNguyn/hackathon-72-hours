# plan.md — [Product Name TBD] — ADC Hackathon 2026 (Stage 2: Job Search & Application)

*(built from intent.md, spec.md, scaffolder.md — this file is written to be self-contained: an engineer with no access to those files should be able to execute every task below as written)*

*(Scoped strictly to the product build — no competition schedule, session times, or submission logistics here. Sequence and dependencies only.)*

## Team & workstreams (3 engineers, run in parallel from hour one)

- **Workstream A — WebView Integration & Content Perception** (highest risk, build/validate first)
- **Workstream B — Flutter app shell, orchestration FSM, UI accessibility**
- **Workstream C — AI integration (OpenAI prompts), voice pipeline logic, testing & demo production**

All three can start simultaneously using the scaffolded stubs from `scaffolder.md`. B and C do not need to wait for A's real results to start — they build against mocked data first, then integrate once A's spike output is known (see Integration Checkpoint below).

---

## Workstream A — WebView Integration & Content Perception

**Owner's goal:** prove and build the component that reads real job-portal/careers-page content and PDF application forms, and can act on the page (fill form fields). This is the single highest-risk, highest-value piece of the whole project — if this doesn't work, nothing else matters.

- [ ] **A1. Spike: confirm the JS-bridge approach can reliably read DOM content from a real job portal/company careers page.** Build a minimal `webview_flutter` host page (per `scaffolder.md`) and load 1–2 real target pages chosen by the team (e.g. VietnamWorks and a real company careers page — confirm the exact pages during the spike, don't assume in advance which one renders cleanly). Inject JavaScript to walk the DOM and extract: image `src` + `alt` values, `<input>`/`<select>`/`<textarea>` fields with their associated labels, and visible text content. Log the extracted structure. **Pass/fail:** if the app can detect and extract at least image `src` URLs and form-field locations from the real page, proceed; if the page is heavily client-side-rendered in a way that leaves little detectable DOM structure at injection time (e.g. content that only appears after complex JS frameworks finish rendering, with no stable selectors), this is a hard blocker — escalate immediately, don't keep building on top of it. This replaces the old Shopee-`AccessibilityService` spike; same "prove the load-bearing assumption first" principle, new target.
- [ ] **A2. Build the JS injection library for DOM reading** — a `.js` asset (per `scaffolder.md`) providing functions to enumerate images lacking meaningful `alt` text, enumerate form fields with their labels/placeholders, and extract the page's readable text content, callable from Dart via `runJavaScriptReturningResult`.
- [ ] **A3. Build the JS injection library for form-filling** — functions to locate a form field (by label/placeholder match, coordinated with Workstream C's field-matching logic) and set its value (`element.value = ...`), dispatching an `input` (and `change`, where needed) event so the host page's own JS recognizes the fill. Include a timeout/verification step: after filling, re-read the field to confirm the value stuck before reporting success.
- [ ] **A4. Build the PDF-parsing integration** — pick and integrate a Flutter PDF library (candidates: `syncfusion_flutter_pdf`, `pdf_text` — confirm the final choice against a real sample application-form PDF, note the choice and why in `spec.md` §1). Extract text and, where the library supports it, distinguish form-field structure from body text.
- [ ] **A5. Error handling for the new failure modes** — page-load failure/timeout in the WebView, unexpected/empty DOM structure, PDF parse failure, or an expected form field not found. Build a simple heuristic per failure mode and expose a "retry" path. Same principle as the old ad-popup-detection task, retargeted: test against real page-load hiccups and any real PDF that fails to parse cleanly, since this may need several real attempts to characterize.
- [ ] **A6. End-to-end manual test against the 1–2 pre-chosen real targets** (decide the exact platform(s)/listing(s)/PDF sample as a team decision, informed by what actually works well from A1 — don't commit to a specific target before confirming it renders cleanly).

## Workstream B — Flutter app shell, orchestration FSM, UI accessibility

**Owner's goal:** the user-facing app and the flow-control logic that ties everything together.

- [ ] **B1. Implement the FSM** (`lib/orchestration/order_flow_fsm.dart` — rename to reflect the new domain if convenient, e.g. `application_flow_fsm.dart`) with states: `Idle → Listening → ParsingIntent → LoadingTarget → ReadingContent → AwaitingUserAction → FillingForm → AwaitingSubmitConfirmation → Done`, plus `Error`/`Retrying` transitions back to the state that failed. Use `ChangeNotifier` + `provider` so the UI reacts to state changes automatically. Write this against **mocked services first** (fake `WebViewControllerService`/`PdfReaderService` returning canned content) so it doesn't block on Workstream A.
- [ ] **B2. Build the UI** (`home_screen.dart`, `voice_trigger_button.dart`, `status_narration_view.dart`) — a single trigger button plus a live text readout mirroring everything being spoken (never audio-only — satisfies WCAG 3.3.1 Error Identification for visible error text). Every interactive widget needs a `Semantics` label — no exceptions, even on a "temporary" debug button. **`status_narration_view.dart` must be a `Semantics(liveRegion: true)` region** — if TTS fails or is muted, TalkBack should still announce status changes from the text alone. Audit every icon (meaningful vs. purely decorative) and give each an explicit `Semantics(label: ...)` or exclude it.
- [ ] **B3. Integrate `speech_to_text` and `flutter_tts`** (`speech_service.dart`, `tts_service.dart`). Implement the STT mitigation chain: pin locale from the language preference, enforce a confidence threshold (start at 0.6, tune empirically) below which the FSM re-prompts instead of proceeding, and surface the n-best hypothesis list to Workstream C's intent-parsing logic.
- [ ] **B4. Settings screen** — language toggle (EN/VI), persisted via `preferences_service.dart` (`SharedPreferences`); also host the (optional) reusable applicant-profile fields used for form-fill (spec.md §8).
- [ ] **B5. Wire B1–B4 together** into a working mocked end-to-end flow (fake job listing read aloud → fake PDF read aloud → fake form-fill → fake submit confirmation) — proves the FSM and UI work correctly *before* real WebView/PDF integration, isolating bugs to one side or the other later.
- [ ] **B6. TalkBack accessibility pass, plus automated scan.** With TalkBack enabled on a real device, navigate the entire app's own UI. Fix any element that's unreachable, unlabeled, or reads incorrectly. Then run **Google's Accessibility Scanner app** against the built APK as a fast supplementary check. Do both **before** the final demo recording — see spec.md's WCAG mapping table for the specific criteria.
- [ ] **B7. Integrate with Workstream A's real `WebViewControllerService`/`PdfReaderService`** once A2–A4 are ready — swap the mocked services for the real WebView/JS-bridge and PDF-parsing calls. This is the **Integration Checkpoint** (see below).

## Workstream C — AI integration, voice pipeline logic, testing & demo production

**Owner's goal:** the "brain" that turns noisy real-world input (voice, messy page DOM, PDF text) into correct decisions, plus proving the whole thing works on camera.

- [ ] **C1. Build `openai_service.dart`** — call types: (a) intent parsing (transcript → structured request, e.g. "read this listing" / "fill and submit this application"), (b) image-to-text (job-description image with no usable alt text → transcribed/described content), (c) DOM-content filtering/summarization (raw extracted DOM text/structure → narratable job-listing summary, ads/nav chrome suppressed), (d) PDF-text structuring (raw PDF text → structured, navigable form content), (e) form-field matching (applicant-provided info → best-matching detected form field). Write and test prompts against **hand-crafted sample data** (mocked DOM/PDF extracts representing what you expect the real target to look like) before real data exists — refine once Workstream A produces real samples from A1/A2/A4.
- [ ] **C2. Build the applicant-info matching/fuzzy-match logic** — matches STT n-best hypotheses and any saved applicant-profile fields against detected form fields (e.g. using string-similarity/edit-distance on label text) before falling back to the OpenAI matching call. First line of defense against transcription distortion and label-text variance across sites.
- [ ] **C3. Write the narration script content** — the actual phrases spoken at each FSM state ("Reading the job description...", "This listing is for [title] at [company], here are the requirements...", "Filling in your name...", "That didn't load as expected, retrying...", final filled-form summary before submit confirmation). Keep phrasing short and unambiguous — this directly affects how clean the final recorded demo sounds.
- [ ] **C4. Environment/secrets setup** — get an OpenAI API key, set up the `.env`/`local.properties` handling per `scaffolder.md` Step 6, and **check with a Day 1 mentor/organizer whether the hackathon provides sponsored API credits** before spending personal money.
- [ ] **C5. Once Workstream A + B are integrated (post-Integration Checkpoint), run repeated real end-to-end tests** on the 1–2 chosen real targets (portal/careers page + PDF form). Log every failure mode seen (wrong content read, form field not found/mismatched, page/PDF parse failure) and feed fixes back to A/B/C as needed. Budget real time for this — it will surface problems the mocked testing couldn't.
- [ ] **C6. Record the demo video** once C5 produces reliably clean runs — multiple takes are fine (pre-recorded submission, not a live demo), keep the cleanest. <5 min, MP4/MOV, 16:9 landscape, slide visible throughout. **Add captions (burned-in or SRT)** — for an accessibility-competition submission, an uncaptioned demo video undercuts the pitch.
- [ ] **C7. Build the slide deck** (.pptx, official template, slides 1–6 fixed sequence) — Problem/Solution/Prototype slides can be drafted early using intent.md content without waiting for the app to be finished; update with real screenshots/numbers once available. Include the explicit "AI-screening bias is out of scope, by design" boundary statement from intent.md §1/§4 — a stated limitation is stronger than an unstated gap a judge finds themselves.

---

## Integration Checkpoint (A + B + C converge)

This is the single most important moment in the build sequence: the point where Workstream A's real DOM/PDF-reading and form-filling output, Workstream B's FSM/UI, and Workstream C's AI layer first run together against a real job portal and a real PDF application form. Everything before this point can be built and tested in isolation against mocks; everything after this point is about fixing what breaks when the pieces meet reality. **Sequence it as: A1 passes → A2–A4 built → B1/B5 mocked flow working → swap in real services (B7) → run real end-to-end tests (C5).** Don't let mocked-only work drag on past the point where A1's result is known — the sooner real integration starts, the more time remains to fix what it surfaces.

## Overall priority order

*(Rubric weights aren't published yet — intent.md §8 is explicitly marked skipped — so priority below is mapped to intent.md's Success Criteria instead, the closest confirmed stand-in.)*

| # | Task | Workstream | Relates to (Success Criteria) | Risk if skipped |
|---|---|---|---|---|
| 1 | A1 — confirm the JS-bridge reads real DOM content | A | All of them — this is the load-bearing assumption of the entire project | Total: if this fails, the whole approach needs to pivot (fallback: narrower target, or a differently-scoped demo) |
| 2 | B1/B5 — FSM + mocked end-to-end flow | B | Criterion 1 (clean demo flow), Criterion 3 (reliable real-target flow) | Without this, there's no flow to integrate real components into |
| 3 | C1/C2 — content filtering/matching + fuzzy-match logic (against mocks first) | C | Criterion 3, Problem barriers #1–#4 (portal noise, image descriptions, PDF structure, field matching) | The core "AI value-add" differentiator — without it this is just a scripted macro, not an AI product |
| 4 | A2–A4 — DOM reader, form-filler, PDF parser | A | Criterion 3 | Blocks the Integration Checkpoint entirely |
| 5 | B3 — real STT/TTS integration | B | Criterion 1, Criterion 3 | Without it there's no voice input, which is the whole interaction model |
| 6 | **Integration Checkpoint** | A+B+C | Criterion 1, 3 | See above — the point of maximum schedule risk |
| 7 | A5 — page/PDF error handling | A | Problem barriers — a named differentiator vs. a page/PDF that silently fails | Weakens the "handles what a plain screen reader can't" pitch, but the flow can still work if no failure occurs during the recorded take (risky to rely on luck) |
| 8 | B6 — TalkBack pass on own UI | B | Criterion 4 (impact/credibility with judges) | Undermines credibility if judges test the app themselves and hit an inaccessible element in your own UI — ironic and damaging |
| 9 | C5 — repeated real testing | C | Criterion 1, 3 | Without this, you're recording an untested flow — high chance of an on-camera failure |
| 10 | C6 — record demo video | C | Criterion 1 (deliverable) | Required submission component |
| 11 | C7 — slide deck | C | Criterion 4, required deliverable | Required submission component |

## Risks & Constraints

- **A1 (the spike) is the load-bearing assumption of the entire project.** If it fails — the real job portal's DOM turns out to be effectively unreadable at injection time (e.g. content behind a heavy client-side-rendering framework with no stable selectors, or content that never stabilizes long enough to extract) — the whole approach needs to pivot immediately, not after more has been built on top of the assumption. Treat a failed A1 as a stop-and-reassess trigger, not a bug to work around. This is the new equivalent of the old "Shopee's accessibility tree might be unreadable" risk.
- **Real job-portal DOM structure is the biggest unknown overall** — some sites use heavy client-side-rendering frameworks that complicate reliable form-field detection (fields that don't exist in the DOM until a user interaction, shadow-DOM-encapsulated widgets, etc.); until real-device testing happens against the actual chosen target(s), the real difficulty is unverified. Don't commit to final narration script wording or a specific target platform until A1 confirms what's actually readable.
- **PDF structure variance** — not every application-form PDF is equally well-tagged; a scanned/image-based PDF (no extractable text layer at all) would need OCR, which is a materially bigger scope add — confirm the chosen sample PDF has an actual text layer before committing to it as the test target.
- **API costs/rate limits** — check for available API credits (C4) before running heavy test volume, especially during C5's repeated real-testing phase.
- **Don't let mocked-only work outrun real integration** — B and C can build against mocks indefinitely without ever discovering the real problems A1/A5 will surface; cap how long any workstream stays mock-only before pulling in real data.

## Success proof (deterministic)

- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes, including FSM transition unit tests (e.g.: `ReadingContent → AwaitingUserAction` on content successfully read; `FillingForm → Retrying → FillingForm` on a recoverable field-fill timeout; `FillingForm → AwaitingSubmitConfirmation` on all fields filled)
- [ ] `flutter build apk --debug` succeeds with no errors
- [ ] Manual: app installs and launches on a clean Android device via the built APK
- [ ] Manual: TalkBack can navigate the entire app's own UI (Workstream B6)
- [ ] Manual: the chosen real target completes the full flow (image-based job description read aloud → portal content narrated → PDF form read aloud → form filled and submitted with narration and a confirm checkpoint before submit) at least once, recorded
- [ ] Manual: at least one real page-load or PDF-parse failure is caught and handled without derailing the flow, demonstrated in testing (even if not necessarily in the final recorded take)

---

## Self-check: could a different engineer implement this without intent.md/spec.md?

Going through each workstream and asking honestly where this plan still leans on outside context:

- **Mostly yes, with gaps patched above rather than left implicit:** (1) the exact target job portal(s)/PDF sample aren't actually known yet — this is stated explicitly as an Open Question (intent.md §7) with an explicit spike (A1) to confirm feasibility before committing, rather than assumed; (2) file paths and class names are given concretely (from scaffolder.md) rather than referenced abstractly; (3) the FSM's actual state names and transition examples are spelled out in the Success Proof section, not just referenced by name.
- **Residual gap, worth naming rather than hiding:** the exact narration wording (C3) and the final choice of target portal(s)/PDF are explicitly left as decisions to make *once real data exists* (post-A1) — a different engineer couldn't write final narration copy or commit to a specific target from this plan alone, but that's intentional: committing to either before knowing what the real DOM/PDF actually looks like would be guessing, not planning.
- **One more implicit dependency:** confidence thresholds (STT gating, fuzzy-match similarity cutoff) are given as starting values ("start at 0.6, tune empirically") rather than fixed constants — a different engineer would need to actually run the app to tune these, which is unavoidable for values that depend on real device/mic/network behavior.
