# Milestone 29 — STT confidence-threshold gating

**One-line goal:** if the recognized transcript's confidence is too low, don't forward it to the AI at all — re-prompt the user instead of acting on a guess.

## Project context
`02-spec.md` §6.1, `06-plan.md` B3: enforce a confidence threshold (start at **0.6**, tune empirically) below which the FSM re-prompts instead of proceeding. This is the exact code path that decides "forward to the LLM or not" — made concrete here, not left as a principle.

## Maps to plan.md task(s)
B3 (part 2 of 3)

## Preconditions
Milestone 28

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit
- `lib/core/constants.dart` — edit (already has `sttConfidenceThreshold = 0.6` stubbed from scaffolding — use it, don't redefine it elsewhere)

## Implementation spec
- After `SpeechService.listen()` returns, **before** firing `VoiceCommandRecognized`, check `result.confidence < AppConstants.sttConfidenceThreshold`.
- **Below threshold:** do **not** fire `VoiceCommandRecognized` at all. Instead, narrate a re-prompt (English: *"Sorry, I didn't catch that, could you repeat?"*; Vietnamese: *"Xin lỗi, tôi chưa nghe rõ, bạn nói lại được không?"*) and remain in `ListeningState`, ready for another `listen()` call.
- **At or above threshold:** fire `VoiceCommandRecognized(transcript)` normally.

## Definition of Done
- [ ] Unit test with a fake `SpeechService` returning `confidence: 0.4`: FSM stays in `ListeningState`, `VoiceCommandRecognized` is never fired, the re-prompt narration is triggered
- [ ] Unit test with `confidence: 0.8`: `VoiceCommandRecognized` fires normally and the FSM advances per milestone 04's transition table

## Size
S
