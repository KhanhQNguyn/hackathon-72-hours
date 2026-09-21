# Milestone 07 — FSM: gated submit + `Done`

**One-line goal:** make the actual, real submit action fire only when the FSM is in `FinalReview`/`AwaitingSubmitConfirmation` and receives an explicit `SubmitConfirmed` event — never inferred from an AI's own response text.

## Project context
This is where the reliability principle from `02-spec.md` §5 becomes real code: *"Checkpoints are enforced as FSM hard-states that gate the real side-effecting action, not left to the AI's own output text... An LLM narrating 'the user confirmed, proceeding' is not, by itself, sufficient to trigger a submit — only an explicit `SubmitConfirmed` event transitioning the FSM out of that state is."* Submitting a job application is consequential and hard to undo, so this gate is the single most safety-critical piece of the FSM.

## Maps to plan.md task(s)
B1 (part 4 of 5)

## Preconditions
Milestones 04–06

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit
- `test/orchestration/application_flow_fsm_test.dart` — edit

## Implementation spec
- `FinalReviewState()` + `SubmitConfirmed` (already stubbed) → `AwaitingSubmitConfirmationState()` (already stubbed) → **the real submit callback fires here, and only here.**
- Recommended shape: make this specific transition path `async` — change `transition()`'s signature to `Future<void> transition(ApplicationFlowEvent event)` (or add a dedicated `Future<void> confirmSubmit()` method used only for this transition, if keeping `transition()` synchronous elsewhere is preferred) — so the real submit call (which will eventually be a `WebViewControllerService` call, once milestone 44 wires it in) can be awaited, and a submit failure routes to `ErrorState` rather than silently landing in `DoneState`.
- **The core contract this milestone must satisfy: there is no code path anywhere else in the app that can invoke the real submit action.** `OpenAiService`'s responses are never checked for "did the AI say to submit" — only the FSM's own event stream decides. Pseudocode:
  ```dart
  if (event is SubmitConfirmed && _state is FinalReviewState) {
    _state = const AwaitingSubmitConfirmationState();
    notifyListeners();
    try {
      await _performRealSubmit(); // wired to a real callback in milestone 44; a no-op/test double until then
      _state = const DoneState();
    } catch (e) {
      _state = ErrorState(failedState: const FinalReviewState(), message: e.toString());
    }
    notifyListeners();
  }
  ```
- For now (before milestone 44), `_performRealSubmit` should be an injectable callback (constructor parameter or field) defaulting to a no-op, so this milestone's tests can inject a fake submit callback and assert on it.

## Definition of Done
- [ ] Unit test: a fake submit-callback spy is invoked exactly once, and only when `SubmitConfirmed` is sent while in `FinalReviewState` — sending `SubmitConfirmed` from any other state (e.g. `Idle`, `FillingFormState`) does not invoke it
- [ ] Unit test: if the fake submit callback throws, the FSM ends in `ErrorState`, not `DoneState`
- [ ] Code-review checklist item (not a test, a manual check): grep the codebase for every call site of the real submit action once milestone 44 wires the real one in, and confirm there is exactly one call site, inside this gated path

## Size
M
