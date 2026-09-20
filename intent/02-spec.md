# spec.md — [Product Name TBD]

*(built from intent.md — see that file for Problem/Users/Outcome/Features/Constraints)*

## 1. Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| App shell (UI) | **Flutter (Dart)** | Already decided in intent.md. Note: the app's *own* visible UI surface is intentionally small — a voice-trigger button, a live status/transcript readout, a language toggle (EN/VI). Most of the "product" happens inside Shopee's UI, not ours. |
| Automation/orchestration layer | **Kotlin `AccessibilityService`** (native Android), bridged to Flutter via a **Platform Channel** (`MethodChannel` + `EventChannel`) | This is the part that reads Shopee's screen and acts on it. Flutter has no wrapper for `AccessibilityService` — it must be written natively and exposed to the Dart side as a channel. This is the highest-risk, highest-value component; build/test it first. |
| AI / NLU + vision | **OpenAI API** — `gpt-4o-mini` for intent parsing (voice command → structured search query) and node-tree filtering/matching (noise/ad suppression, "find the right element"); `gpt-4o` (vision) as a **fallback** when an accessibility node is unlabeled/mislabeled — send a cropped screenshot of the ambiguous region, ask it to identify the real content. | Team's choice. `gpt-4o-mini` keeps per-call cost/latency low for the frequent filtering/matching calls; vision is only invoked on the fallback path, not every step, to control cost and latency. Matching/filtering prompts should take the target app's package name and node tree as generic parameters rather than hardcoding Shopee-specific field names, so the same logic could point at a different app (e.g. Grab, Be, XanhSM) later without a prompt rewrite — only Shopee is built/tested now, but the interface is written generically from the start. |
| Voice I/O | **`speech_to_text`** + **`flutter_tts`** (Flutter plugins wrapping Android `SpeechRecognizer`/`TextToSpeech`) — on-device | Same underlying on-device engines as originally decided, free, no network dependency. Using the existing Flutter plugins instead of hand-writing a custom platform channel for STT/TTS saves real build time — custom native channel work is reserved for the `AccessibilityService`, which has no existing plugin. |
| Local storage | **`SharedPreferences`** (simple key-value: language setting, last search) — no real database | No user accounts, no server-side state, no multi-device sync needed for an MVP. A full DB would be solving a problem this project doesn't have. |
| Deployment | **Debug/release APK, sideloaded** | No Play Store (review timelines don't fit 72h — see intent.md Constraints). No hosting/infra needed since there's no backend. |
| Supporting tools | AI coding assistant (Claude Code) for implementation velocity on the Kotlin service + Flutter channel + prompt engineering; Git for version control, following the team's own intent → spec → schema/endpoints → code flow | Per intent.md's engineering-approach note: coding speed buys robustness on the narrow scope, not broader scope. |

**No custom backend for the MVP.** The Flutter app calls the OpenAI API directly over HTTPS from the device. This is a deliberate scope cut, not an oversight — see the Security note in Section 3 for the trade-off this creates and how to phrase it safely in the deck.

## 2. API

- **This project has no API it hosts** — there's no server, so no REST/GraphQL surface to design or version. "API" here means **how the app calls out** to OpenAI's REST API (`chat/completions`, both text and vision-capable calls).
- **Call pattern:** synchronous request/response per step (e.g., one call to parse the voice command into a search intent; one call per screen to filter/match the accessibility tree; occasional vision calls only on the fallback path). Each call should carry minimal context (the relevant subtree/screenshot, not the whole app state) to control latency and token cost.
- **Roadmap (not built now):** if this became a real product, a thin backend would proxy these calls so the API key isn't shipped in the client — see Section 3.

## 3. Middleware

- No server middleware exists (no server). The on-device equivalents:
  - **Error/timeout handling around every `AccessibilityService` action** — if a tap/scroll doesn't produce the expected screen change within a timeout, treat it as a recoverable failure: narrate ("that didn't load as expected, retrying...") and retry once or twice before giving up and asking the user for guidance. This is the "built-in robustness" principle from intent.md's Success Criteria, implemented concretely here.
  - **Local logging** (Logcat + a lightweight in-app event log) for debugging during the build, not a production observability stack.
  - **OpenAI rate limits:** be aware of per-minute request/token limits on whichever tier the team is on; the filtering/matching call happens frequently (every screen), so a burst of retries during error recovery could hit limits — worth a simple backoff, not a queueing system.
- **⚠️ Security note, flag this to the team explicitly:** shipping the OpenAI API key inside the client APK is insecure (anyone who decompiles the APK can extract it and rack up charges on your account). This is a known, deliberate shortcut for a 72-hour hackathon prototype — not something to ship as a real product. Mitigate minimally: keep the key out of the Git repo (use a local `local.properties`/`.env` excluded via `.gitignore`, injected at build time), and mention "backend key-proxy" as roadmap/future-work in the deck rather than pretending this is production-secure.

## 4. Authentication

- **This app has no authentication of its own.** There are no user accounts, no login screen, nothing to sign into — the app relies on the user already being signed into **Shopee** via their own existing Shopee app/session on the device. Our app never touches Shopee credentials; it only reads/acts on whatever screen Shopee is already showing.
- WCAG 2.2 SC 3.3.8 (Accessible Authentication) therefore doesn't directly apply to this MVP, since we implement no auth flow ourselves. **If the roadmap ever adds accounts** (e.g., to save preferred addresses, order history, or custom voice shortcuts), that future auth flow must avoid CAPTCHA-only or memory/puzzle-based verification, per SC 3.3.8 — worth a one-line roadmap note in the deck, not something to build now.

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
│ Kotlin AccessibilityService    │  │ OpenAI API                │
│ (native Android)               │  │ - gpt-4o-mini: intent      │
│ - reads Shopee's node tree     │  │   parsing, node filtering/ │
│ - taps/scrolls/fills on Shopee │◄─┤   matching                 │
│ - reports node tree/screenshots│  │ - gpt-4o (vision):         │
│   up to the AI layer for       │  │   fallback for mislabeled  │
│   filtering/matching decisions │  │   elements                 │
└───────────────┬─────────────────┘  └──────────────────────────┘
                │ reads/acts on screen (same access level as TalkBack)
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Shopee app (real, unmodified, third-party)                   │
└─────────────────────────────────────────────────────────────┘
```

- **Why this architecture fits a 3-day build:** it's client-only — no server to stand up, deploy, or keep alive during the demo/evaluation window (one less thing to break). The two genuinely hard components (the `AccessibilityService` and the AI filtering/matching logic) are isolated behind a single platform-channel boundary, so they can be built and tested somewhat independently by different team members in parallel.
- **Single points of failure to test early:** the platform channel itself (Flutter↔Kotlin communication) and the `AccessibilityService`'s ability to read real Shopee — both are exactly what the spike (still pending) needs to validate before the rest of the build depends on them.

### Software architecture pattern: layered + Finite State Machine (FSM)

Classic web patterns (N-Tier, modular monolith) describe how a *server* is organized — this project has no server, so they don't map directly. What's used instead:

- **Orchestration core = a Finite State Machine**, not a loose collection of feature code. The Domain section below is already a strict sequential pipeline with defined pause/retry points (`Idle → Listening → ParsingIntent → Matching → AwaitingProductConfirmation → Executing → AwaitingPaymentHandoff → Done`, with `Error/Retrying` transitions back to prior states). Modeling it explicitly as an FSM gives a single source of truth for "where the flow is," makes retry logic (Success Criteria's "built-in robustness") a normal state transition rather than special-cased code, and makes the flow unit-testable without a live phone/mic/Shopee.
- **Layers around the FSM** (mirrors the 8 bounded contexts in Section 6, not a generic web split):
  1. **UI** — Flutter widgets, purely presentational, driven by current FSM state (effectively MVVM, with the FSM as the "ViewModel")
  2. **Orchestration** — the FSM itself, pure Dart, no platform/network code inside it
  3. **Services** — thin, swappable wrapper classes per external dependency (`SpeechService`, `OpenAIService`, `AccessibilityBridge`) — mockable, so UI work can proceed in parallel with the native service still being built
  4. **Native** — the Kotlin `AccessibilityService`, exposed only via the platform channel, no business logic inside it
- **Deliberately not using:** full Clean Architecture (entities/use-cases/repositories/DI ceremony). It's the right call for long-lived production software, but the setup cost isn't worth it for 3 people/72 hours — the layered+FSM approach gets most of the readability/parallel-build benefit for a fraction of the cost.

## 6. Domain

Bounded contexts / responsibilities, mapped to Core Features in intent.md:

1. **Voice Command Intake** — on-device `SpeechRecognizer` (STT), silence/end-of-speech detection, handoff of transcript to the NLU call. **Distortion mitigation, decided:**
   - Set STT locale explicitly per session (`vi-VN` or `en-US`, via the existing language toggle) rather than auto-detecting mixed-language speech.
   - Use a constrained command phrasing ("Order [item] on Shopee") — shorter, more predictable utterances transcribe more reliably than open-ended speech.
   - Check the STT **confidence score**; below a threshold, don't forward to the LLM — narrate a re-ask ("didn't catch that, could you repeat the item?") instead of processing garbage input.
   - Pass the STT **n-best hypothesis list** (not just the top guess) to the LLM/matcher, and fuzzy-match against the known 2–3 supported products (per intent.md scope) rather than trusting exact transcribed spelling — "Phở Bò"/"Fuh Bo"/"Pho Bow" should all resolve to the same item.
   - **The existing product-match confirmation checkpoint (see #5 below) is the final safety net** — even a mis-transcription that slips past the above gets caught when the user hears "I found X, confirm?" and says no. Worth stating explicitly in the deck as a designed-in error-correction loop, not an incidental nicety.
2. **Intent Parsing** — OpenAI (`gpt-4o-mini`, text-only — audio is transcribed on-device first, not sent to the API directly; see rationale above) call that turns the transcript into a structured search intent (product name, any constraints mentioned). *(Feature 1)*
3. **Screen Perception** — `AccessibilityService` captures the current Shopee node tree; on ambiguity, captures a screenshot crop for the vision fallback. *(Feature 2, Problem pain point #3)*
4. **AI Filtering & Matching** — suppresses ad/promo/irrelevant nodes, matches the parsed intent against real product nodes, produces the "best match" for confirmation readback. *(Feature 2)*
5. **Confirmation Manager** — the two hard-stop checkpoints (product match, pre-payment) — pauses the flow, narrates the decision point, waits for explicit user input before continuing. *(Feature 2 & 4, the notification-vs-confirmation distinction)*
6. **Action Orchestrator** — drives the actual taps/scrolls/text-fill on Shopee once confirmed; narrates every step in between (not just at checkpoints). *(Feature 3)*
7. **Error Recovery** — timeout/retry/narrate-and-recover wrapper around the Orchestrator, handling popup ads and unexpected screen states. *(Problem pain point #2, Success Criteria's "built-in robustness" principle)*
8. **Payment Handoff** — detects arrival at the payment/OTP screen and deliberately stops, reading the full order summary aloud. *(Feature 4)*

## 7. Design Requirements — WCAG 2.2 AA, mapped to Android/Flutter

WCAG 2.2 is technically a *web content* standard, so it doesn't apply verbatim to a native Android app — but its principles map cleanly, and this table exists so the team can honestly say in the deck "we designed against WCAG 2.2 AA from the architecture up," backed by a real mapping rather than a claim.

**Important meta-point:** the *automation target* is Shopee (a third-party app we don't control the accessibility of — we can only read/compensate for it). But **our own app's UI** (the small Flutter shell — trigger button, status screen, language toggle) is fully ours to build right, and it must itself be usable by a blind user via TalkBack, or the whole product is self-defeating. The table below applies to *our own UI*, not to Shopee's (which we can't change).

| WCAG 2.2 AA criterion | Android/Flutter equivalent | How this project implements it |
|---|---|---|
| **1.4.3 Contrast (Minimum)** — 4.5:1 text, 3:1 large text | Flutter theme color tokens checked against contrast ratio | Define the app's color palette with contrast-checked pairs from the start (use a contrast checker during design, not after); since blind users are the primary audience, this mainly matters for low-vision users and sighted teammates testing the app |
| **1.4.11 Non-text Contrast** — 3:1 for UI components/icons | Same, applied to buttons/icons/focus indicators | Trigger button and status icons meet 3:1 against background |
| **1.4.4 Resize Text** — up to 200% without loss of function | Flutter's `MediaQuery.textScaleFactor` / respecting system font size | Use scalable text units, not fixed pixel sizes that break layout when the OS font-size setting is increased |
| **1.4.1 Use of Color** — don't convey info by color alone | N/A mostly (voice-first UI) | Status conveyed via narration (TTS) + text label, never color alone, for the rare visual state (e.g. a colored status dot) |
| **2.5.8 Target Size (Minimum)** — 24×24 CSS px minimum | Android Material Design guideline is 48dp minimum, which already exceeds the WCAG floor | Use standard Material button sizing (48dp+) for the trigger button and any tappable elements — trivially satisfied by not overriding Flutter/Material defaults |
| **2.4.7 Focus Visible / 2.4.11 Focus Not Obscured** | TalkBack's focus highlight, driven by proper widget semantics | Ensure every interactive Flutter widget has a `Semantics` label and is reachable in a logical TalkBack traversal order — test with TalkBack on, not just by looking at the screen |
| **2.1.1 Keyboard (all functionality without a mouse)** | Android equivalent: full functionality operable via TalkBack gestures / external switch access, not dependent on precise touch/drag | Since the whole point of the app is voice-first operation, this is largely satisfied by design — but verify the minimal touch UI (trigger button) is also fully operable via TalkBack swipe-navigation, not just direct tap |
| **3.3.2 Labels or Instructions** | `Semantics(label: ...)` on every interactive widget | Trigger button, language toggle, and any settings must have clear, descriptive accessibility labels — not just visual text (icons need labels too) |
| **3.3.1 Error Identification** | TTS narration of errors, not silent failure or visual-only error text | When the Action Orchestrator hits a recoverable error (Section 3), the error is **spoken**, not just logged or shown as text the user can't see |
| **4.1.2 Name, Role, Value** | Correct Flutter `Semantics`/widget types (use real `Button`, not a styled `GestureDetector` with no semantic role) | Avoid "div-soup" equivalent in Flutter — don't build custom-painted widgets with no semantic role when a standard accessible widget exists |
| **3.3.8 Accessible Authentication** | N/A for MVP (no auth flow — see Section 4) | Documented as roadmap-only consideration if accounts are ever added |

**Testing method, not just design:** before the demo recording, run the app's own UI with **TalkBack enabled** and confirm it's fully navigable — this is the cheapest, highest-credibility accessibility validation step available, and it directly demonstrates "we practice what we preach" to judges.

### Items from accessibility-wcag.md not yet covered above, closed here

`accessibility-wcag.md` is written generically for web apps; cross-checking its checklist against this project surfaced a few items the table above didn't yet address:

| Checklist item (as written, web-oriented) | Android/Flutter equivalent | Where it's implemented |
|---|---|---|
| `<html lang="...">` declared | Flutter `MaterialApp(locale: ...)` set from the language preference, not left to device default | `preferences_service.dart` drives this — same source of truth as the STT/TTS locale (spec.md §6.1), so language stays consistent everywhere |
| Images have meaningful alt text; decorative images get `alt=""` | `Semantics(label: ...)` for meaningful icons; `ExcludeSemantics` or `Semantics(label: '')` for purely decorative ones | App's icon set is minimal (trigger button, status icon) — audit each one explicitly rather than assuming Flutter's defaults are already correct |
| Error messages announced to screen readers (`aria-live`/`aria-describedby`) | `Semantics(liveRegion: true)` on the status/narration text widget | **Important addition:** `status_narration_view.dart` (scaffolder.md) should be a live region — if TTS narration fails or is muted, TalkBack still announces status text changes automatically. This makes the "narrate every step" requirement (intent.md Core Feature 3) redundant-safe, not dependent on TTS alone. |
| Drag-and-drop needs a click/tap alternative | N/A | No drag interactions exist anywhere in this app's own UI |
| Automated accessibility scan tool (axe/Lighthouse are web-only) | **Android equivalent: Google's Accessibility Scanner app**, run against the built APK | Add to Workstream B6 (plan.md) as a supplement to manual TalkBack testing — catches basic issues faster, same "~30-40% coverage, doesn't replace manual testing" caveat applies |
| Video/audio has captions or a transcript | Applies to the **submission video itself**, not just the app | Add burned-in or SRT captions to the demo video (plan.md Workstream C6) — for an accessibility-competition submission, an uncaptioned demo video undercuts the pitch; this is a credibility point worth the small extra effort |

## 8. Local State (schema.md skipped — see decision below)

No `schema.md`/`models.md` file — there's no database, so there are no models/relationships to document. The template itself recommends skipping this when the system is small and simple; this project qualifies (zero models). The only persisted state, documented here instead of in a separate file:

| Key | Type | Notes |
|---|---|---|
| `language_pref` | string (`en` \| `vi`) | Drives STT locale + TTS voice + UI text |
| `last_search_query` | string, optional | Convenience only — not required for MVP functionality |

Stored via Flutter `SharedPreferences`. No user accounts, no server-side persistence, nothing else to model.

---

## ⚠️ To fill in as the build progresses

- [x] endpoints.md — **not needed**, confirmed. No backend, so no hosted routes to document. The project's one outbound API call (to OpenAI) is documented in Section 2 above, since it's a call this app *makes*, not an endpoint it *serves*.
- [ ] Confirm OpenAI API tier/rate limits and whether the hackathon provides any API credits (worth checking with organisers/mentors on Day 1 — some hackathons sponsor AI API credits)
- [ ] Run the `AccessibilityService` + real Shopee spike (still pending, highest-risk unknown — see intent.md)
- [x] schema.md/endpoints.md — **not needed**, confirmed. No backend, no database; the one bit of local state is documented in Section 8 above instead.
- [ ] TalkBack pass on the app's own UI before final demo recording