# Milestone 04 — FSM contracts + linear front-half transitions

**One-line goal:** finalize the FSM's state/event class fields and implement the front half of the flow: `Idle` through `AwaitingUserAction`.

## Project context
`job_access_assist`'s orchestration core is a Finite State Machine (`ApplicationFlowFsm`, a `ChangeNotifier`) that is the single source of truth for where the flow is. Full state diagram: `Idle → Listening → ParsingIntent → LoadingTarget → ReadingContent → AwaitingUserAction → FillingForm(perFieldConfirmLoop) → FinalReview → [EditingField(fieldId) → FinalReview]* → AwaitingSubmitConfirmation → Done`, with `Error`/`Retrying` transitions back to whatever state failed. Full background: `02-spec.md` §5.

The state (`ApplicationFlowState`, sealed class) and event (`ApplicationFlowEvent`, sealed class) type hierarchies already exist as compiling stubs from the initial scaffolding pass, with an `ApplicationFlowFsm.transition()` method that currently just throws `UnimplementedError`. This milestone replaces that for the front-half path only.

## Maps to plan.md task(s)
B1 (part 1 of 5)

## Preconditions
None — start immediately. Pure Dart, no dependency on the WebView/AI layers.

## Files touched
- `lib/orchestration/application_flow_state.dart` — edit
- `lib/orchestration/application_flow_event.dart` — edit
- `lib/orchestration/application_flow_fsm.dart` — edit
- `test/orchestration/application_flow_fsm_test.dart` — edit (replace the scaffold's single smoke test with real transition tests)

## Implementation spec
**Existing stub classes to confirm (no changes needed, listed for completeness):** `IdleState`, `ListeningState`, `ParsingIntentState`, `LoadingTargetState`, `ReadingContentState`, `AwaitingUserActionState` — all no-field marker classes extending `ApplicationFlowState`.

**Existing stub events to confirm (no changes needed):** `TriggerPressed`, `VoiceCommandRecognized(String transcript)`, `IntentParsed`, `TargetLoaded`, `ContentRead`, `ListingConfirmed`.

**One real field addition needed now, ahead of milestone 05's use of it:** `FillingFormState` currently only has `currentFieldId`. Add `final List<String> remainingFieldIds` — the ordered queue of field ids still to process after the current one. This is a concrete implementation decision this milestone is making (not something `02-spec.md` specifies at this level of detail).

**`ApplicationFlowFsm.transition(ApplicationFlowEvent event)` — implement exactly this sub-path:**
```
Idle --TriggerPressed--> Listening
Listening --VoiceCommandRecognized--> ParsingIntent
ParsingIntent --IntentParsed--> LoadingTarget
LoadingTarget --TargetLoaded--> ReadingContent
ReadingContent --ContentRead--> AwaitingUserAction
AwaitingUserAction --ListingConfirmed--> FillingForm(currentFieldId: <first field>, remainingFieldIds: <rest>)
```
- The "first field"/"rest" split for the final transition above comes from wherever the caller supplies the ordered field list (not decided in this milestone — for now, accept it as a parameter on the `ListingConfirmed` event or a separate setter; whichever is simplest to wire, since the real field-list source, `dom_reader.js`, doesn't exist until milestone 09+).
- **Any event not valid for the current state is a no-op**: log a warning via `Logger`, do not throw, do not change state. This is a defensive design choice worth stating explicitly since `02-spec.md` doesn't specify invalid-transition behavior at this level.

## Definition of Done
- [ ] One unit test per arrow in the sub-path above (6 tests)
- [ ] Unit test: an event invalid for the current state (e.g. `SubmitConfirmed` while in `IdleState`) leaves `fsm.state` unchanged and does not throw
- [ ] `flutter analyze` clean, `flutter test` passes

## Size
M
