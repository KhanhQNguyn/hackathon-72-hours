# Milestone 35 — Wire B1–B4 end-to-end against mocks

**One-line goal:** prove the entire FSM + UI + voice + settings stack works correctly as a full flow, before real WebView/PDF integration ever enters the picture.

## Project context
`06-plan.md` B5: wiring B1–B4 together into a working mocked end-to-end flow "proves the FSM and UI work correctly *before* real WebView/PDF integration, isolating bugs to one side or the other later." This is the payoff milestone for everything built in milestones 04–34's B-track.

## Maps to plan.md task(s)
B5 (part 2 of 2)

## Preconditions
Milestones 04–08 (FSM), 26–27 (UI), 28–30 (voice), 31–33 (settings — or its fallback per the open decision in milestone 33), 34 (mocks)

## Files touched
- `lib/app.dart` — edit (dependency-injection point: inject `FakeWebViewControllerService`/`FakePdfReaderService` via `Provider` for this milestone; milestone 44 swaps in the real ones later)

## Implementation spec
- Manually drive the full flow via the real UI: trigger → speak a command → mocked listing read aloud → mocked PDF read aloud → mocked field-by-field fill → `FinalReview` → submit-confirmed → `Done` — using **real** STT/TTS/FSM, with **only** the WebView/PDF layer faked.

## Definition of Done
- [ ] A full run from `TriggerPressed` to `DoneState` completes using only real B-layer code plus A-layer fakes, with no crashes, and narration audible at every step
- [ ] This is the milestone that proves the FSM and UI work correctly *before* real WebView/PDF integration — per `06-plan.md` B5's own stated purpose; do not skip straight to milestone 44 without this passing first

## Size
M
