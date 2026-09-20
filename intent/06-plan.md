# plan.md — Shopee Voice Assist (working title) — ADC Hackathon 2026

*(built from intent.md, spec.md, scaffolder.md — this file is written to be self-contained: an engineer with no access to those files should be able to execute every task below as written)*

*(Scoped strictly to the product build — no competition schedule, session times, or submission logistics here. Sequence and dependencies only.)*

## Team & workstreams (3 engineers, run in parallel from hour one)

- **Workstream A — Native Android / `AccessibilityService`** (highest risk, build/validate first)
- **Workstream B — Flutter app shell, orchestration FSM, UI accessibility**
- **Workstream C — AI integration (OpenAI prompts), voice pipeline logic, testing & demo production**

All three can start simultaneously using the scaffolded stubs from `scaffolder.md`. B and C do not need to wait for A's real results to start — they build against mocked data first, then integrate once A's spike output is known (see Integration Checkpoint below).

---

## Workstream A — Native Android / `AccessibilityService`

**Owner's goal:** prove and build the component that reads Shopee's screen and acts on it. This is the single highest-risk, highest-value piece of the whole project — if this doesn't work, nothing else matters.

- [ ] **A1. Spike: confirm `AccessibilityService` can read the real Shopee app.** Write a minimal `AccessibilityService` (in `android/app/src/main/kotlin/.../accessibility/ShopeeAccessibilityService.kt`, per `scaffolder.md`), enable it via Android Settings → Accessibility on a real device with the real Shopee app installed (Vietnam package, commonly `com.shopee.vn` — **confirm the exact package name on-device via `adb shell pm list packages | grep shopee`, don't assume**). Open Shopee's search results page and a product detail page; log the full `AccessibilityNodeInfo` tree (text, `contentDescription`, `className`, bounds) to Logcat. **Pass/fail:** if product names and buttons are readable in the dumped tree, proceed; if the tree is mostly empty/generic (e.g., everything renders as unlabeled `View` nodes inside a `WebView` or custom canvas), this is a hard blocker — escalate immediately, don't keep building on top of it.
- [ ] **A2. Build `NodeTreeSerializer.kt`** — converts the live node tree into a JSON structure (list of `{text, contentDescription, className, bounds, clickable}`) sendable to Dart over the platform channel/to OpenAI for filtering.
- [ ] **A3. Build `ActionExecutor.kt`** — given a target node (by bounds or node ID), perform `ACTION_CLICK`, `ACTION_SET_TEXT` (for address/notes fields), and scroll-to-reveal actions. Include a timeout: if the expected screen change doesn't happen within ~2 seconds of an action, return a "no-op/unexpected-state" result rather than silently continuing (this feeds Workstream B's FSM retry logic).
- [ ] **A4. Build `AccessibilityChannelHandler.kt`** — exposes A2/A3 to Flutter via `MethodChannel` (request node tree, perform action) and `EventChannel` (stream node-tree-changed events, e.g. when a popup ad appears).
- [ ] **A5. Ad-popup detection.** Using real Shopee, identify what a popup ad looks like in the node tree (a new top-level window/overlay node appearing). Build a simple heuristic (e.g., detect an unexpected new window with a dismiss/close button) and expose a "dismiss popup" action. Test against real ad occurrences — this may need several real sessions on Shopee to catch an ad in the act.
- [ ] **A6. End-to-end manual test against the 2–3 pre-chosen products** (decide the exact 2–3 products/search terms as a team decision, informed by what actually works well from A1 — don't commit to specific products before confirming they render cleanly in the accessibility tree).

## Workstream B — Flutter app shell, orchestration FSM, UI accessibility

**Owner's goal:** the user-facing app and the flow-control logic that ties everything together.

- [ ] **B1. Implement the FSM** (`lib/orchestration/order_flow_fsm.dart`) with states: `Idle → Listening → ParsingIntent → Matching → AwaitingProductConfirmation → Executing → AwaitingPaymentHandoff → Done`, plus `Error`/`Retrying` transitions back to the state that failed. Use `ChangeNotifier` + `provider` so the UI reacts to state changes automatically. Write this against **mocked services first** (fake `AccessibilityBridgeService` returning canned node trees) so it doesn't block on Workstream A.
- [ ] **B2. Build the UI** (`home_screen.dart`, `voice_trigger_button.dart`, `status_narration_view.dart`) — a single trigger button plus a live text readout mirroring everything being spoken (never audio-only — a sighted teammate or judge should be able to follow along by reading, and this satisfies WCAG 3.3.1 Error Identification for visible error text). Every interactive widget needs a `Semantics` label — no exceptions, even on a "temporary" debug button.
- [ ] **B3. Integrate `speech_to_text` and `flutter_tts`** (`speech_service.dart`, `tts_service.dart`). Implement the STT mitigation chain: pin locale from the language preference (not auto-detect), enforce a confidence threshold (start at 0.6, tune empirically) below which the FSM re-prompts instead of proceeding, and surface the n-best hypothesis list (not just the top guess) to Workstream C's matching logic.
- [ ] **B4. Settings screen** — language toggle (EN/VI), persisted via `preferences_service.dart` (`SharedPreferences`).
- [ ] **B5. Wire B1–B4 together** into a working mocked end-to-end flow (fake product match → fake confirmation → fake "checkout" → fake payment handoff) — this proves the FSM and UI work correctly *before* real native integration, isolating bugs to one side or the other later.
- [ ] **B6. TalkBack accessibility pass.** With TalkBack enabled on a real device, navigate the entire app's own UI. Fix any element that's unreachable, unlabeled, or reads incorrectly. Do this **before** the final demo recording, not after — see spec.md's WCAG mapping table for the specific criteria (contrast, touch target size, focus order, name/role/value).
- [ ] **B7. Integrate with Workstream A's real `AccessibilityChannelHandler`** once A4 is ready — swap the mocked `AccessibilityBridgeService` for the real platform channel calls. This is the **Integration Checkpoint** (see below).

## Workstream C — AI integration, voice pipeline logic, testing & demo production

**Owner's goal:** the "brain" that turns noisy real-world input (voice, messy UI trees) into correct decisions, plus proving the whole thing works on camera.

- [ ] **C1. Build `openai_service.dart`** — three call types: (a) intent parsing (transcript → structured `{product_query}`), (b) node-tree filtering/matching (raw JSON node list → best-match product + confidence, suppressing ad/promo nodes), (c) vision fallback (screenshot crop → identify actual content when a node is unlabeled/generic). Write and test prompts against **hand-crafted sample JSON** (mocked node trees representing what you expect Shopee's tree to look like) before real data exists — refine once Workstream A produces real samples from A1/A2.
- [ ] **C2. Build `fuzzy_match_service.dart`** — matches STT n-best hypotheses against the known 2–3 product names (e.g. using a string-similarity library or a simple edit-distance check) before falling back to the OpenAI intent-parsing call. This is the first line of defense against transcription distortion (spec.md's mitigation chain).
- [ ] **C3. Write the narration script content** — the actual phrases spoken at each FSM state ("Found Phở Bò, 45,000 VND, from [seller], add to cart?", "Adding to cart...", "That didn't load as expected, retrying...", final order summary before payment handoff). Keep phrasing short and unambiguous — this is UX content, not just engineering, and directly affects how clean the final recorded demo sounds.
- [ ] **C4. Environment/secrets setup** — get an OpenAI API key, set up the `.env`/`local.properties` handling per `scaffolder.md` Step 6, and **check with a Day 1 mentor/organizer whether the hackathon provides sponsored API credits** before spending personal money.
- [ ] **C5. Once Workstream A + B are integrated (post-Integration Checkpoint), run repeated real end-to-end tests** on the 2–3 chosen products. Log every failure mode seen (wrong match, ad interruption not caught, action timeout) and feed fixes back to A/B/C as needed. Budget real time for this — it will surface problems the mocked testing couldn't.
- [ ] **C6. Record the demo video** once C5 produces reliably clean runs — multiple takes are fine (this is a pre-recorded submission, not a live demo — see intent.md Success Criteria), keep the cleanest. <5 min, MP4/MOV, 16:9 landscape, slide visible throughout per submission guidelines.
- [ ] **C7. Build the slide deck** (.pptx, official template, slides 1–6 fixed sequence) — Problem/Solution/Prototype slides can be drafted early using intent.md content without waiting for the app to be finished; update with real screenshots/numbers once available.

---

## Integration Checkpoint (A + B + C converge)

This is the single most important moment in the build sequence: the point where Workstream A's real native output, Workstream B's FSM/UI, and Workstream C's AI logic first run together against real Shopee. Everything before this point can be built and tested in isolation against mocks; everything after this point is about fixing what breaks when the pieces meet reality. **Sequence it as: A1 passes → A2–A4 built → B1/B5 mocked flow working → swap in real channel (B7) → run real end-to-end tests (C5).** Don't let mocked-only work drag on past the point where A1's result is known — the sooner real integration starts, the more time remains to fix what it surfaces.

## Overall priority order

*(Rubric weights aren't published yet — intent.md §8 is explicitly marked skipped — so priority below is mapped to intent.md's Success Criteria instead, which is the closest confirmed stand-in.)*

| # | Task | Workstream | Relates to (Success Criteria) | Risk if skipped |
|---|---|---|---|---|
| 1 | A1 — confirm `AccessibilityService` reads real Shopee | A | All of them — this is the load-bearing assumption of the entire project | Total: if this fails, the whole approach needs to pivot (fallback: narrower scope, or a differently-scoped demo) |
| 2 | B1/B5 — FSM + mocked end-to-end flow | B | Criterion 1 (clean demo flow), Criterion 3 (reliable 2-3 product flow) | Without this, there's no flow to integrate real components into |
| 3 | C1/C2 — matching + fuzzy-match logic (against mocks first) | C | Criterion 3, Problem pain points #1–#3 (ad noise, mislabeled elements, distortion) | The core "AI value-add" differentiator — without it this is just a scripted macro, not an AI product |
| 4 | A2–A4 — serializer, action executor, channel handler | A | Criterion 3 | Blocks the Integration Checkpoint entirely |
| 5 | B3 — real STT/TTS integration | B | Criterion 1, Criterion 3 | Without it there's no voice input, which is the whole interaction model |
| 6 | **Integration Checkpoint** | A+B+C | Criterion 1, 3 | See above — the point of maximum schedule risk |
| 7 | A5 — ad-popup detection | A | Problem pain point #2 — a named differentiator vs. raw VoiceOver | Weakens the core "AI handles what VoiceOver can't" pitch, but the flow can still work without it if no ad appears during the recorded take (risky to rely on luck) |
| 8 | B6 — TalkBack pass on own UI | B | Criterion 4 (impact/credibility with judges) | Undermines credibility if judges test the app themselves and hit an inaccessible element in your own UI — ironic and damaging |
| 9 | C5 — repeated real testing | C | Criterion 1, 3 | Without this, you're recording an untested flow — high chance of an on-camera failure |
| 10 | C6 — record demo video | C | Criterion 1 (deliverable) | Required submission component |
| 11 | C7 — slide deck | C | Criterion 4, required deliverable | Required submission component |

## Risks & Constraints

- **A1 (the spike) is the load-bearing assumption of the entire project.** If it fails — Shopee's accessibility tree turns out to be mostly unlabeled/generic (e.g. rendered inside a `WebView` or custom canvas) — the whole approach needs to pivot immediately, not after more has been built on top of the assumption. Treat a failed A1 as a stop-and-reassess trigger, not a bug to work around.
- **Shopee's real UI is the biggest unknown overall** — ads, mislabeled elements, and layout differences between products are exactly what A1/A5/C1 exist to handle, but until real-device testing happens, the actual difficulty is unverified. Don't commit to a specific narration script or final product list until A1 confirms what's actually readable.
- **API costs/rate limits** — check for available API credits (C4) before running heavy test volume, especially during C5's repeated real-testing phase.
- **Don't let mocked-only work outrun real integration** — B and C can build against mocks indefinitely without ever discovering the real problems A1/A5 will surface; cap how long any workstream stays mock-only before pulling in real data.

## Success proof (deterministic)

- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes, including FSM transition unit tests (e.g.: `Matching → AwaitingProductConfirmation` on a match found; `AwaitingProductConfirmation → Matching` on user rejection; `Executing → Retrying → Executing` on a recoverable action timeout; `Executing → AwaitingPaymentHandoff` on reaching checkout)
- [ ] `flutter build apk --debug` succeeds with no errors
- [ ] Manual: app installs and launches on a clean Android device via the built APK
- [ ] Manual: TalkBack can navigate the entire app's own UI (Workstream B6)
- [ ] Manual: each of the 2–3 chosen products completes the full flow (voice command → confirmed match → auto-filled checkout with narration → address read aloud → clean stop at payment handoff) at least once, recorded
- [ ] Manual: at least one real ad-popup interruption is caught and handled without derailing the flow, demonstrated in testing (even if not necessarily in the final recorded take)

---

## Self-check: could a different engineer implement this without intent.md/spec.md?

Going through each workstream and asking honestly where this plan still leans on outside context:

- **Mostly yes, with three gaps I've patched above rather than left implicit:** (1) the exact Shopee package name isn't actually known yet — I added an explicit `adb` command to confirm it rather than assuming `com.shopee.vn`; (2) file paths and class names are given concretely (from scaffolder.md) rather than referenced abstractly; (3) the FSM's actual state names and transition examples are spelled out in the Success Proof section, not just referenced by name.
- **Residual gap, worth naming rather than hiding:** the exact narration wording (C3) and the final choice of 2–3 products are explicitly left as decisions to make *once real data exists* (post-A1) — a different engineer couldn't write final narration copy or commit to specific products from this plan alone, but that's intentional: committing to either before knowing what Shopee's tree actually looks like would be guessing, not planning. The plan makes that dependency explicit rather than pretending to resolve it prematurely.
- **One more implicit dependency:** confidence thresholds (STT gating, fuzzy-match similarity cutoff) are given as starting values ("start at 0.6, tune empirically") rather than fixed constants — a different engineer would need to actually run the app to tune these, which is unavoidable for values that depend on real device/mic/network behavior, not something a planning document can specify in advance.
