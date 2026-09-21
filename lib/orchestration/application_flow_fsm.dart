import 'package:flutter/foundation.dart';

import 'application_flow_event.dart';
import 'application_flow_state.dart';

export 'application_flow_event.dart';
export 'application_flow_state.dart';

/// Owns the application-flow state machine described in spec.md §5:
/// `Idle -> Listening -> ParsingIntent -> LoadingTarget ->
/// ReadingContent -> AwaitingUserAction ->
/// FillingForm(perFieldConfirmLoop) -> FinalReview ->
/// [EditingField(fieldId) -> FinalReview]* -> AwaitingSubmitConfirmation
/// -> Done`, with `Error`/`Retrying` transitions back to the state that
/// failed. Exposed as a `ChangeNotifier` so the UI layer reacts to state
/// changes automatically (spec.md §5, layered architecture note).
class ApplicationFlowFsm extends ChangeNotifier {
  // Reassigned by the real transition() implementation (plan.md
  // Workstream B1); intentionally not final.
  // ignore: prefer_final_fields
  ApplicationFlowState _state = const IdleState();

  ApplicationFlowState get state => _state;

  // TODO: implement the real transition table per spec.md §5. In
  // particular:
  // - FillingFormState must not advance to FinalReviewState until every
  //   detected field has fired a FieldConfirmed event followed by
  //   AllFieldsConfirmed (perFieldConfirmLoop) — no single
  //   fill-everything-then-readback pass.
  // - EditingFieldState is reachable only from FinalReviewState and
  //   must loop back to FinalReviewState on FieldEditConfirmed, never
  //   anywhere else — a loop-back, not a restart.
  // - CaptchaEncountered (checkpoint 3, plan.md task B1b) pauses the
  //   flow regardless of which state it's fired from; CaptchaResolved
  //   resumes it into the state it interrupted.
  // - ErrorOccurred transitions to ErrorState(failedState: _state, ...);
  //   RetryRequested transitions back to that failedState, not to Idle.
  void transition(ApplicationFlowEvent event) {
    throw UnimplementedError(
      'FSM transition logic is not implemented in this scaffolding pass '
      '— see plan.md Workstream B1.',
    );
  }
}
