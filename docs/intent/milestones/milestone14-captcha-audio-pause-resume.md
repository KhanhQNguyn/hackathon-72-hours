# Milestone 14 — CAPTCHA audio-challenge-first + FSM pause/resume

**One-line goal:** try the CAPTCHA's own accessible audio-challenge option first; if none exists, pause the FSM, narrate the hand-off, and resume exactly where it left off once the user says "continue."

## Project context
`01-intent.md` §4, checkpoint 3: *"First try the CAPTCHA's own accessible audio-challenge option if the page offers one (many providers, including reCAPTCHA, ship this specifically for screen-reader users — using it is using an intended accessible path, not circumventing security). If no audio option exists, the flow stops and hands control to the user explicitly... waiting for the user's resume command before proceeding."*

**⚠️ Open decision, not resolved by `01-intent.md`/`02-spec.md`, used here as a recommendation — confirm with the team before treating it as final:** `02-spec.md` §5's official FSM state list has no dedicated "paused for CAPTCHA" state. **Recommended: `CaptchaPendingState(ApplicationFlowState interruptedState)`**, mirroring the already-existing `ErrorState(failedState, message)` pattern — consistent with how the FSM already handles "pause here, remember where to go back to." If the team prefers a different representation (e.g. a boolean flag on the interrupted state instead of a wrapper state), this milestone's code will need to change accordingly, but proceed with the wrapper-state design below unless told otherwise, so work isn't blocked on the open question.

## Maps to plan.md task(s)
B1b (part 2 of 2)

## Preconditions
Milestone 13, milestone 07 (reuses the pause-and-resume pattern established by `Error`/`Retrying`)

## Files touched
- `assets/js/dom_reader.js` — edit (`audioButtonSelector` resolution)
- `lib/orchestration/application_flow_state.dart` — edit (add `CaptchaPendingState`)
- `lib/orchestration/application_flow_event.dart` — no change (`CaptchaEncountered`/`CaptchaResolved` already stubbed from scaffolding)
- `lib/orchestration/application_flow_fsm.dart` — edit
- `lib/services/tts_service.dart` — edit (narration call site)

## Implementation spec
- **Audio-challenge search:** within/adjacent to the detected CAPTCHA iframe, look for a clickable element whose `aria-label` or `title` contains `audio` (case-insensitive) — the standard reCAPTCHA/hCaptcha accessible-audio-challenge affordance. Poll for it (5 attempts × 400ms, since the widget may still be rendering when first detected). If found: click it automatically, treat the CAPTCHA as resolved with **no user pause needed**, narrate: *"Đã dùng tùy chọn âm thanh cho CAPTCHA"* ("Used the audio option for the CAPTCHA").
- **If no audio option found within the poll window:**
  ```dart
  fsm.transition(CaptchaEncountered());
  // -> CaptchaPendingState(interruptedState: fsm.state)
  await ttsService.speak("Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé");
  ```
  (exact narration string, quoted verbatim from `01-intent.md` §4 — do not rephrase).
  FSM stays in `CaptchaPendingState` until a `CaptchaResolved` event fires — triggered when STT recognizes a "tiếp tục"/"continue" command (wire this recognition check into milestone 28's speech pipeline; do not build a separate parallel STT path just for this).
- **On `CaptchaResolved`:** transition returns to `(state as CaptchaPendingState).interruptedState` **exactly** — this is why the wrapper carries the interrupted state instead of being a bare flag.

## Definition of Done
- [ ] Unit test: FSM in `FillingFormState('phone', [...])`, receives `CaptchaEncountered` → state becomes `CaptchaPendingState(FillingFormState('phone', [...]))`; receiving `CaptchaResolved` → state becomes `FillingFormState('phone', [...])` again (exact field equality, not just "some FillingFormState")
- [ ] Manual: trigger a real test-mode reCAPTCHA challenge popup (the audio button typically only appears once the challenge popup itself is open, not on the initial checkbox) and confirm the audio-first path is attempted before falling back to narrate-and-pause

## Size
M
