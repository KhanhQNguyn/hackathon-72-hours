/// Sealed class of FSM states. See spec.md §5 architecture note for the
/// full state diagram: `Idle -> Listening -> ParsingIntent ->
/// LoadingTarget -> ReadingContent -> AwaitingUserAction ->
/// FillingForm(perFieldConfirmLoop) -> FinalReview ->
/// [EditingField(fieldId) -> FinalReview]* -> AwaitingSubmitConfirmation
/// -> Done`, with `Error`/`Retrying` transitions back to the state that
/// failed.
sealed class ApplicationFlowState {
  const ApplicationFlowState();
}

class IdleState extends ApplicationFlowState {
  const IdleState();
}

class ListeningState extends ApplicationFlowState {
  const ListeningState();
}

class ParsingIntentState extends ApplicationFlowState {
  const ParsingIntentState();
}

class LoadingTargetState extends ApplicationFlowState {
  const LoadingTargetState();
}

class ReadingContentState extends ApplicationFlowState {
  const ReadingContentState();
}

/// Checkpoint 1 (selecting a company/listing) is decided while in this
/// state — see spec.md §6 "Confirmation Manager".
class AwaitingUserActionState extends ApplicationFlowState {
  const AwaitingUserActionState();
}

/// The field-by-field confirm loop (spec.md §5, §6 "Form-Fill
/// Orchestrator"): does not advance to `FinalReviewState` until every
/// detected field has been individually confirmed. `currentFieldId`
/// tracks which field is currently being announced/confirmed;
/// `remainingFieldIds` is the ordered queue of fields still to process
/// after the current one (milestone04).
class FillingFormState extends ApplicationFlowState {
  final String currentFieldId;
  final List<String> remainingFieldIds;

  const FillingFormState(this.currentFieldId, this.remainingFieldIds);

  @override
  bool operator ==(Object other) =>
      other is FillingFormState &&
      other.currentFieldId == currentFieldId &&
      _listEquals(other.remainingFieldIds, remainingFieldIds);

  @override
  int get hashCode => Object.hash(currentFieldId, Object.hashAll(remainingFieldIds));
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lightweight summary state — not necessarily a full re-read of every
/// field, since each was already confirmed individually in
/// `FillingFormState`. From here, the user can request "sửa lại
/// [field]" (see `EditingFieldState`) or confirm submission.
class FinalReviewState extends ApplicationFlowState {
  const FinalReviewState();
}

/// Reachable only from `FinalReviewState`. Re-collects/re-confirms one
/// field, then loops back to `FinalReviewState` — a loop-back, not a
/// full restart. Can be entered any number of times before submit.
class EditingFieldState extends ApplicationFlowState {
  final String fieldId;

  const EditingFieldState(this.fieldId);

  @override
  bool operator ==(Object other) =>
      other is EditingFieldState && other.fieldId == fieldId;

  @override
  int get hashCode => fieldId.hashCode;
}

/// Checkpoint 2 (confirm before final submit) and checkpoint 3 (CAPTCHA
/// encounter) are both handled while the flow is at or around this
/// state — see spec.md §6 "Confirmation Manager" and plan.md task B1b.
class AwaitingSubmitConfirmationState extends ApplicationFlowState {
  const AwaitingSubmitConfirmationState();
}

class DoneState extends ApplicationFlowState {
  const DoneState();
}

/// A retryable failure — page-load failure, PDF parse failure, form
/// field not found, etc. (spec.md §3 "Error Recovery"). Carries the
/// state to return to on retry.
class ErrorState extends ApplicationFlowState {
  final ApplicationFlowState failedState;
  final String message;

  const ErrorState({required this.failedState, required this.message});

  @override
  bool operator ==(Object other) =>
      other is ErrorState &&
      other.failedState == failedState &&
      other.message == message;

  @override
  int get hashCode => Object.hash(failedState, message);
}

class RetryingState extends ApplicationFlowState {
  const RetryingState();
}
