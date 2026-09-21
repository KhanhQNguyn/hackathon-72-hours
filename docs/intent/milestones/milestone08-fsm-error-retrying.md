# Milestone 08 — FSM: `Error`/`Retrying` generic wrapper

**One-line goal:** a state-agnostic mechanism so any recoverable failure, from any state, narrates, retries automatically once or twice, and only then asks the user, then returns to exactly the state that failed.

## Project context
`02-spec.md` §3 (Middleware / built-in robustness principle): treat a recoverable failure as narrate ("that didn't load as expected, retrying...") and retry once or twice before giving up and asking the user for guidance — this applies uniformly to page-load failures, PDF parse failures, and form-field-not-found cases (milestones 22–24 each plug into this).

## Maps to plan.md task(s)
B1 (part 5 of 5)

## Preconditions
Milestone 04

## Files touched
- `lib/orchestration/application_flow_fsm.dart` — edit
- `test/orchestration/application_flow_fsm_test.dart` — edit

## Implementation spec
- `ErrorOccurred(String message)` (already stubbed) fired from **any** state → `ErrorState(failedState: currentState, message: message)` (already stubbed with these two fields).
- Internally, immediately after entering `ErrorState`, automatically attempt one retry: transition to `RetryingState()` (already stubbed, currently a no-field marker), re-run whatever action failed (the actual retried action is owned by whichever caller triggered `ErrorOccurred` — this milestone only owns the state machinery, not the retried action itself), then:
  - Retry succeeds → return to `failedState` exactly (not `Idle`, not a fresh state).
  - Retry also fails → **stay in `ErrorState`**, now requiring an explicit user `RetryRequested` event (already stubbed) rather than looping a third time automatically. `RetryRequested` also returns to `failedState`.
- This milestone builds the **general-purpose** mechanism; milestones 22–24 wire specific failure sources (page-load, PDF parse, field-not-found) into `ErrorOccurred` — this file does not implement those specific triggers.

## Definition of Done
- [ ] Unit test: `ErrorOccurred` fired from `LoadingTargetState`, from `FillingFormState('x', [])`, and from `FinalReviewState` all correctly wrap that exact state as `ErrorState.failedState`
- [ ] Unit test: two consecutive automatic-retry failures leave the FSM in `ErrorState` (not attempting a third automatic retry)
- [ ] Unit test: `RetryRequested` while in `ErrorState` returns to `failedState` exactly

## Size
S
