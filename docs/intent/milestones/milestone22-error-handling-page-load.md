# Milestone 22 — Error handling: page-load failure/timeout

**One-line goal:** treat a WebView page that fails or times out loading as a recoverable failure — narrate, retry, and only then ask the user — instead of an unhandled crash or silent hang.

## Project context
`02-spec.md` §3: *"if an injected script doesn't return the expected result, a page doesn't finish loading, or PDF parsing throws, treat it as a recoverable failure: narrate ('that didn't load as expected, retrying...') and retry once or twice before giving up and asking the user for guidance."* This milestone wires the page-load-specific trigger into the generic `Error`/`Retrying` machinery from milestone 08.

## Maps to plan.md task(s)
A5 (part 1 of 3)

## Preconditions
Milestone 08 (generic Error/Retrying wrapper), milestone 12 (WebView loading infrastructure)

## Files touched
- `lib/services/webview_controller_service.dart` — edit
- `lib/orchestration/application_flow_fsm.dart` — edit

## Implementation spec
- `loadTarget()` wraps the `InAppWebViewController` load in a timeout: **15 seconds** (generous for a mobile network, still bounded), using `onLoadStop` as the success signal and a `Timer` as the failure path.
- On timeout or `onReceivedError`, throw a typed `PageLoadException(String message)`.
- FSM: any state catching a `PageLoadException` fires `ErrorOccurred(message)` → this flows into milestone 08's already-built `ErrorState`/`RetryingState` machinery. Use the **exact** narration string from `02-spec.md` §3: *"that didn't load as expected, retrying..."*.

## Definition of Done
- [ ] Loading a deliberately unreachable URL (e.g. a wrong port) triggers `PageLoadException` within ~15s, the FSM enters `ErrorState`, the narration is spoken, and one automatic retry is attempted
- [ ] Unit test: `ErrorState(failedState: FillingFormState('phone', [...]), ...)` + `RetryRequested` → returns to that exact `FillingFormState`, not `Idle`

## Size
M
