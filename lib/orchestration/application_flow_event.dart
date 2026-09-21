/// Events that drive `ApplicationFlowFsm` transitions. See spec.md §5.
sealed class ApplicationFlowEvent {
  const ApplicationFlowEvent();
}

class TriggerPressed extends ApplicationFlowEvent {
  const TriggerPressed();
}

class VoiceCommandRecognized extends ApplicationFlowEvent {
  final String transcript;

  const VoiceCommandRecognized(this.transcript);
}

class IntentParsed extends ApplicationFlowEvent {
  const IntentParsed();
}

class TargetLoaded extends ApplicationFlowEvent {
  const TargetLoaded();
}

class ContentRead extends ApplicationFlowEvent {
  const ContentRead();
}

/// Checkpoint 1 — selecting a company/listing. Carries the ordered list
/// of detected field ids to fill next (milestone04 decision: this is how
/// the field list reaches `FillingFormState` — the real source of this
/// list is the DOM-reading layer, milestone09+). An empty list means the
/// form has no fields to fill; the FSM skips straight to `FinalReview`.
class ListingConfirmed extends ApplicationFlowEvent {
  final List<String> fieldIds;

  /// fieldId -> detected type (e.g. `'file'`), passed through to
  /// `FillingFormState.fieldTypes` (milestone21). Optional/named so
  /// existing single-positional-argument call sites keep compiling.
  final Map<String, String> fieldTypes;

  const ListingConfirmed(this.fieldIds, {this.fieldTypes = const {}});
}

/// Fired once per field in the field-by-field confirm loop (spec.md
/// §5) — does not by itself mean every field is done; see
/// `AllFieldsConfirmed`.
class FieldConfirmed extends ApplicationFlowEvent {
  final String fieldId;

  const FieldConfirmed(this.fieldId);
}

class AllFieldsConfirmed extends ApplicationFlowEvent {
  const AllFieldsConfirmed();
}

/// "sửa lại [field]" — requested from `FinalReviewState` (spec.md §5).
class EditFieldRequested extends ApplicationFlowEvent {
  final String fieldId;

  const EditFieldRequested(this.fieldId);
}

class FieldEditConfirmed extends ApplicationFlowEvent {
  const FieldEditConfirmed();
}

/// Checkpoint 3 — CAPTCHA encounter (spec.md §5, plan.md task B1b).
/// Audio-challenge is tried first if the page offers one; otherwise the
/// flow narrates and hands control to the user, resuming only on
/// `CaptchaResolved`.
class CaptchaEncountered extends ApplicationFlowEvent {
  const CaptchaEncountered();
}

class CaptchaResolved extends ApplicationFlowEvent {
  const CaptchaResolved();
}

/// Checkpoint 2 — confirm before final submit.
class SubmitConfirmed extends ApplicationFlowEvent {
  const SubmitConfirmed();
}

/// `retryAction`, if supplied, lets the FSM attempt exactly one automatic
/// retry (via `RetryingState`) before settling into `ErrorState` —
/// opt-in per call site (milestone08), since not every failure should be
/// auto-retried (e.g. milestone24's "field not found" case is skipped,
/// not retried). Returns `true` on success, `false`/throws on failure.
class ErrorOccurred extends ApplicationFlowEvent {
  final String message;
  final Future<bool> Function()? retryAction;

  const ErrorOccurred(this.message, {this.retryAction});
}

class RetryRequested extends ApplicationFlowEvent {
  const RetryRequested();
}

/// Fired when the heuristic pre-filter (milestones 10/11) finds zero
/// candidates for a field the flow needs to fill — a distinct case from
/// a low-confidence match (milestone39, out of this range). Advances the
/// per-field loop exactly like `FieldConfirmed`, but callers narrate a
/// different message ("this form doesn't seem to have a field for X —
/// skipping it") and never enter `ErrorState`, since retrying can't
/// produce a field that isn't there (milestone24).
class FieldSkippedNotFound extends ApplicationFlowEvent {
  final String fieldId;

  const FieldSkippedNotFound(this.fieldId);
}

/// Returns the FSM to `IdleState` from any state — the user cancelled, or
/// a finished/failed run is being restarted (milestone35). Without it
/// `DoneState`/`ErrorState` would be dead ends and the trigger button
/// could never start a second run.
class FlowReset extends ApplicationFlowEvent {
  const FlowReset();
}
