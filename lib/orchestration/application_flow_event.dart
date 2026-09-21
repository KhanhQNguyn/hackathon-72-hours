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

/// Checkpoint 1 — selecting a company/listing.
class ListingConfirmed extends ApplicationFlowEvent {
  const ListingConfirmed();
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

class ErrorOccurred extends ApplicationFlowEvent {
  final String message;

  const ErrorOccurred(this.message);
}

class RetryRequested extends ApplicationFlowEvent {
  const RetryRequested();
}
