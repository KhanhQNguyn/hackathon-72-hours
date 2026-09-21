import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
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
/// failed, and `CaptchaPending` (milestone14) pausing/resuming any state.
/// Exposed as a `ChangeNotifier` so the UI layer reacts to state changes
/// automatically (spec.md §5, layered architecture note).
///
/// `ErrorOccurred` is fired by whatever caller catches a recoverable
/// failure — e.g. a `PageLoadException` from `WebViewControllerService`
/// (milestone22) or a `PdfParseException` from `PdfReaderService`
/// (milestone23) both route through the same generic `ErrorState`/
/// `RetryingState` machinery built in milestone08; this class has no
/// separate handling per failure source, by design.
///
/// `FillingFormState.currentFieldType` (milestone21) is how a future
/// per-field-loop orchestrator — not this class, which stays pure Dart
/// with no platform calls, mirroring `CaptchaCheckpointHandler` — decides
/// whether to call `WebViewControllerService.fillField()` or, for a
/// `'file'` field, `FilePickerService.pickCvFile()` +
/// `WebViewControllerService.triggerFileChooser()` instead, before
/// firing `FieldConfirmed`/`FieldSkippedNotFound` either way. The FSM
/// itself doesn't branch on field type; it just carries the information
/// the caller needs to.
class ApplicationFlowFsm extends ChangeNotifier {
  // Reassigned on every transition; intentionally not final.
  // ignore: prefer_final_fields
  ApplicationFlowState _state = const IdleState();

  /// The real, side-effecting submit action (milestone07). Defaults to a
  /// no-op until milestone44 wires in the real WebViewControllerService
  /// call. This is the ONLY place in the app that should ever invoke the
  /// real submit action — see transition()'s SubmitConfirmed case.
  final Future<void> Function() _performRealSubmit;

  ApplicationFlowFsm({Future<void> Function()? performRealSubmit})
      : _performRealSubmit = performRealSubmit ?? (() async {});

  ApplicationFlowState get state => _state;

  /// Applies [event] to the current state per spec.md §5's state
  /// diagram. Any event not valid for the current state is a no-op
  /// (logged, not thrown) — a defensive design choice, since spec.md
  /// doesn't specify invalid-transition behavior at this level
  /// (milestone04).
  Future<void> transition(ApplicationFlowEvent event) async {
    final current = _state;

    switch (event) {
      // --- Linear front-half path (milestone04) ---
      case TriggerPressed():
        if (current is IdleState) {
          _setState(const ListeningState());
        } else {
          _invalidTransition(event, current);
        }

      case VoiceCommandRecognized():
        if (current is ListeningState) {
          _setState(const ParsingIntentState());
        } else {
          _invalidTransition(event, current);
        }

      case IntentParsed():
        if (current is ParsingIntentState) {
          _setState(const LoadingTargetState());
        } else {
          _invalidTransition(event, current);
        }

      case TargetLoaded():
        if (current is LoadingTargetState) {
          _setState(const ReadingContentState());
        } else {
          _invalidTransition(event, current);
        }

      case ContentRead():
        if (current is ReadingContentState) {
          _setState(const AwaitingUserActionState());
        } else {
          _invalidTransition(event, current);
        }

      case ListingConfirmed(:final fieldIds, :final fieldTypes):
        if (current is AwaitingUserActionState) {
          if (fieldIds.isEmpty) {
            // No fields detected on this form — nothing to fill, skip
            // straight to FinalReview rather than throwing on `.first`
            // of an empty list. Not explicitly specified by milestone04;
            // a defensive, minor implementation decision.
            _setState(const FinalReviewState());
          } else {
            _setState(
              FillingFormState(
                fieldIds.first,
                fieldIds.skip(1).toList(),
                fieldTypes: fieldTypes,
              ),
            );
          }
        } else {
          _invalidTransition(event, current);
        }

      // --- FillingForm per-field confirm loop (milestone05) ---
      case FieldConfirmed(:final fieldId):
        if (current is FillingFormState && current.currentFieldId == fieldId) {
          _advanceFillingForm(current);
        } else {
          // Guards against confirming a field that isn't the one
          // currently being asked about — the exact failure mode this
          // loop exists to prevent (milestone05).
          _invalidTransition(event, current);
        }

      // Zero-candidates case (milestone24) — distinct event from
      // FieldConfirmed so callers can narrate differently, but the same
      // advance-the-loop mechanics; never routes through ErrorState.
      case FieldSkippedNotFound(:final fieldId):
        if (current is FillingFormState && current.currentFieldId == fieldId) {
          _advanceFillingForm(current);
        } else {
          _invalidTransition(event, current);
        }

      case AllFieldsConfirmed():
        // Internal/informational marker — FieldConfirmed already drives
        // the FinalReview transition when the queue empties, so this
        // event carries no state transition of its own.
        break;

      // --- FinalReview / EditingField loop-back (milestone06) ---
      case EditFieldRequested(:final fieldId):
        if (current is FinalReviewState) {
          _setState(EditingFieldState(fieldId));
        } else {
          _invalidTransition(event, current);
        }

      case FieldEditConfirmed():
        if (current is EditingFieldState) {
          // Exactly this loop-back, never to FillingFormState — the
          // other already-confirmed fields must not be touched
          // (milestone06).
          _setState(const FinalReviewState());
        } else {
          _invalidTransition(event, current);
        }

      // --- Gated submit + Done (milestone07) ---
      case SubmitConfirmed():
        if (current is FinalReviewState) {
          _setState(const AwaitingSubmitConfirmationState());
          try {
            // The single call site for the real submit action, in the
            // whole app — gated on FSM state, never on trusting an AI's
            // own output text (spec.md §5).
            await _performRealSubmit();
            _setState(const DoneState());
          } catch (e) {
            _setState(
              ErrorState(
                failedState: const FinalReviewState(),
                message: e.toString(),
              ),
            );
          }
        } else {
          _invalidTransition(event, current);
        }

      // --- Error / Retrying generic wrapper (milestone08) ---
      case ErrorOccurred(:final message, :final retryAction):
        final failedState = current;
        if (retryAction == null) {
          _setState(ErrorState(failedState: failedState, message: message));
        } else {
          _setState(const RetryingState());
          bool succeeded;
          try {
            succeeded = await retryAction();
          } catch (_) {
            succeeded = false;
          }
          if (succeeded) {
            _setState(failedState);
          } else {
            _setState(
              ErrorState(failedState: failedState, message: message),
            );
          }
        }

      case RetryRequested():
        if (current is ErrorState) {
          _setState(current.failedState);
        } else {
          _invalidTransition(event, current);
        }

      // --- Abort / restart (milestone35) ---
      case FlowReset():
        _setState(const IdleState());

      // --- Checkpoint 3: CAPTCHA pause/resume (milestone13/14) ---
      case CaptchaEncountered():
        // Allowed from any state, mirroring ErrorOccurred — a CAPTCHA
        // can appear at any point in the flow (search, fill, review,
        // submit), not just one specific state.
        _setState(CaptchaPendingState(interruptedState: current));

      case CaptchaResolved():
        if (current is CaptchaPendingState) {
          // Returns to the exact interrupted state — this is why
          // CaptchaPendingState wraps it instead of being a bare flag
          // (milestone14).
          _setState(current.interruptedState);
        } else {
          _invalidTransition(event, current);
        }
    }
  }

  /// Shared advance-the-per-field-loop mechanics for both
  /// `FieldConfirmed` (milestone05) and `FieldSkippedNotFound`
  /// (milestone24) — identical state transition, different triggering
  /// event so callers can narrate differently.
  void _advanceFillingForm(FillingFormState current) {
    if (current.remainingFieldIds.isEmpty) {
      _setState(const FinalReviewState());
    } else {
      _setState(
        FillingFormState(
          current.remainingFieldIds.first,
          current.remainingFieldIds.skip(1).toList(),
          fieldTypes: current.fieldTypes,
        ),
      );
    }
  }

  void _setState(ApplicationFlowState newState) {
    _state = newState;
    notifyListeners();
  }

  void _invalidTransition(
    ApplicationFlowEvent event,
    ApplicationFlowState current,
  ) {
    Logger.log(
      'FSM: ignoring ${event.runtimeType} while in ${current.runtimeType}',
    );
  }
}
