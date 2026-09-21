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

  /// fieldId -> detected type (e.g. `'file'`), from
  /// `DomFormField.type` (milestone11). Defaults to empty — optional,
  /// backward-compatible data-only extension (milestone21). The FSM
  /// itself never acts on this (it stays pure Dart, no platform code,
  /// per spec.md §5) — the orchestrating caller driving the per-field
  /// loop is responsible for checking `currentFieldType` and routing a
  /// `'file'` field to `FilePickerService.pickCvFile()` instead of
  /// `WebViewControllerService.fillField()`.
  final Map<String, String> fieldTypes;

  const FillingFormState(
    this.currentFieldId,
    this.remainingFieldIds, {
    this.fieldTypes = const {},
  });

  /// The current field's detected type, if known (milestone21).
  String? get currentFieldType => fieldTypes[currentFieldId];

  @override
  bool operator ==(Object other) =>
      other is FillingFormState &&
      other.currentFieldId == currentFieldId &&
      _listEquals(other.remainingFieldIds, remainingFieldIds) &&
      _mapEquals(other.fieldTypes, fieldTypes);

  @override
  int get hashCode => Object.hash(
        currentFieldId,
        Object.hashAll(remainingFieldIds),
        Object.hashAllUnordered(fieldTypes.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
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

/// Checkpoint 3 — paused for a CAPTCHA encounter (01-intent.md §4,
/// 02-spec.md §6 "Confirmation Manager"). Not part of `02-spec.md` §5's
/// originally-documented state list — added here per milestone14's
/// recommendation, mirroring `ErrorState(failedState, message)`'s
/// wrapper pattern. **Flagged as an open decision in milestone14's own
/// file** — confirm with the team before treating this representation as
/// final; if the team prefers a different one (e.g. a boolean flag on
/// the interrupted state), this class and the FSM cases that use it will
/// need to change together.
class CaptchaPendingState extends ApplicationFlowState {
  final ApplicationFlowState interruptedState;

  const CaptchaPendingState({required this.interruptedState});

  @override
  bool operator ==(Object other) =>
      other is CaptchaPendingState && other.interruptedState == interruptedState;

  @override
  int get hashCode => interruptedState.hashCode;
}
