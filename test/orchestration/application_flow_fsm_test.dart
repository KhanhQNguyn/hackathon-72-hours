import 'package:flutter_test/flutter_test.dart';

import 'package:job_access_assist/orchestration/application_flow_fsm.dart';

// Unit tests for FSM state transitions, per spec.md §5 (testable without
// a live phone/mic/network). Covers milestones 04-08.
void main() {
  group('milestone04 — contracts + linear front-half transitions', () {
    test('FSM starts in IdleState', () {
      final fsm = ApplicationFlowFsm();
      expect(fsm.state, isA<IdleState>());
    });

    test('Idle --TriggerPressed--> Listening', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      expect(fsm.state, isA<ListeningState>());
    });

    test('Listening --VoiceCommandRecognized--> ParsingIntent', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('read this listing'));
      expect(fsm.state, isA<ParsingIntentState>());
    });

    test('ParsingIntent --IntentParsed--> LoadingTarget', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      expect(fsm.state, isA<LoadingTargetState>());
    });

    test('LoadingTarget --TargetLoaded--> ReadingContent', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      expect(fsm.state, isA<ReadingContentState>());
    });

    test('ReadingContent --ContentRead--> AwaitingUserAction', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      expect(fsm.state, isA<AwaitingUserActionState>());
    });

    test(
      'AwaitingUserAction --ListingConfirmed--> FillingForm(first, rest)',
      () async {
        final fsm = ApplicationFlowFsm();
        await fsm.transition(const TriggerPressed());
        await fsm.transition(const VoiceCommandRecognized('x'));
        await fsm.transition(const IntentParsed());
        await fsm.transition(const TargetLoaded());
        await fsm.transition(const ContentRead());
        await fsm.transition(
          const ListingConfirmed(['name', 'phone', 'email']),
        );
        expect(fsm.state, const FillingFormState('name', ['phone', 'email']));
      },
    );

    test(
      'AwaitingUserAction --ListingConfirmed([])--> FinalReview '
      '(no fields to fill)',
      () async {
        final fsm = ApplicationFlowFsm();
        await fsm.transition(const TriggerPressed());
        await fsm.transition(const VoiceCommandRecognized('x'));
        await fsm.transition(const IntentParsed());
        await fsm.transition(const TargetLoaded());
        await fsm.transition(const ContentRead());
        await fsm.transition(const ListingConfirmed([]));
        expect(fsm.state, isA<FinalReviewState>());
      },
    );

    test('an event invalid for the current state is a no-op', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const SubmitConfirmed());
      expect(fsm.state, isA<IdleState>());
    });
  });

  group('milestone05 — FillingForm per-field confirm loop', () {
    test('FieldConfirmed advances to the next field', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed(['name', 'phone', 'email']));
      await fsm.transition(const FieldConfirmed('name'));
      expect(fsm.state, const FillingFormState('phone', ['email']));
    });

    test('FieldConfirmed on the last field moves to FinalReview', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed(['email']));
      await fsm.transition(const FieldConfirmed('email'));
      expect(fsm.state, isA<FinalReviewState>());
    });

    test('FieldConfirmed with the wrong field id is a no-op', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed(['name', 'phone']));
      await fsm.transition(const FieldConfirmed('phone')); // wrong — current is 'name'
      expect(fsm.state, const FillingFormState('name', ['phone']));
    });
  });

  group('milestone06 — FinalReview + EditingField loop-back', () {
    test('FinalReview --EditFieldRequested--> EditingField', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed([]));
      expect(fsm.state, isA<FinalReviewState>());

      await fsm.transition(const EditFieldRequested('phone'));
      expect(fsm.state, const EditingFieldState('phone'));
    });

    test('EditingField --FieldEditConfirmed--> FinalReview', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed([]));
      await fsm.transition(const EditFieldRequested('phone'));

      await fsm.transition(const FieldEditConfirmed());
      expect(fsm.state, isA<FinalReviewState>());
    });

    test(
      'loop-back can happen twice for two different fields without ever '
      'entering FillingFormState',
      () async {
        final fsm = ApplicationFlowFsm();
        await fsm.transition(const TriggerPressed());
        await fsm.transition(const VoiceCommandRecognized('x'));
        await fsm.transition(const IntentParsed());
        await fsm.transition(const TargetLoaded());
        await fsm.transition(const ContentRead());
        await fsm.transition(const ListingConfirmed([]));

        await fsm.transition(const EditFieldRequested('phone'));
        expect(fsm.state, isNot(isA<FillingFormState>()));
        await fsm.transition(const FieldEditConfirmed());
        expect(fsm.state, isA<FinalReviewState>());

        await fsm.transition(const EditFieldRequested('email'));
        expect(fsm.state, isNot(isA<FillingFormState>()));
        await fsm.transition(const FieldEditConfirmed());
        expect(fsm.state, isA<FinalReviewState>());
      },
    );
  });

  group('milestone07 — gated submit + Done', () {
    Future<ApplicationFlowFsm> fsmAtFinalReview({
      Future<void> Function()? performRealSubmit,
    }) async {
      final fsm = ApplicationFlowFsm(performRealSubmit: performRealSubmit);
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed([]));
      return fsm;
    }

    test(
      'SubmitConfirmed from FinalReview invokes the real submit callback '
      'exactly once and ends in Done',
      () async {
        var callCount = 0;
        final fsm = await fsmAtFinalReview(
          performRealSubmit: () async {
            callCount++;
          },
        );

        await fsm.transition(const SubmitConfirmed());

        expect(callCount, 1);
        expect(fsm.state, isA<DoneState>());
      },
    );

    test(
      'SubmitConfirmed from any other state does NOT invoke the real '
      'submit callback',
      () async {
        var callCount = 0;
        final fsm = ApplicationFlowFsm(
          performRealSubmit: () async {
            callCount++;
          },
        );

        // Idle
        await fsm.transition(const SubmitConfirmed());
        expect(callCount, 0);

        // FillingFormState
        await fsm.transition(const TriggerPressed());
        await fsm.transition(const VoiceCommandRecognized('x'));
        await fsm.transition(const IntentParsed());
        await fsm.transition(const TargetLoaded());
        await fsm.transition(const ContentRead());
        await fsm.transition(const ListingConfirmed(['name']));
        expect(fsm.state, isA<FillingFormState>());
        await fsm.transition(const SubmitConfirmed());
        expect(callCount, 0);
        expect(fsm.state, isA<FillingFormState>());
      },
    );

    test(
      'if the real submit callback throws, the FSM ends in ErrorState, '
      'not DoneState',
      () async {
        final fsm = await fsmAtFinalReview(
          performRealSubmit: () async {
            throw Exception('network down');
          },
        );

        await fsm.transition(const SubmitConfirmed());

        expect(fsm.state, isA<ErrorState>());
        expect((fsm.state as ErrorState).failedState, isA<FinalReviewState>());
      },
    );
  });

  group('milestone08 — Error/Retrying generic wrapper', () {
    test('ErrorOccurred wraps LoadingTargetState correctly', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      expect(fsm.state, isA<LoadingTargetState>());

      await fsm.transition(const ErrorOccurred('load failed'));

      expect(fsm.state, isA<ErrorState>());
      expect((fsm.state as ErrorState).failedState, isA<LoadingTargetState>());
      expect((fsm.state as ErrorState).message, 'load failed');
    });

    test('ErrorOccurred wraps FillingFormState correctly', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed(['x']));
      expect(fsm.state, const FillingFormState('x', []));

      await fsm.transition(const ErrorOccurred('fill failed'));

      expect(
        (fsm.state as ErrorState).failedState,
        const FillingFormState('x', []),
      );
    });

    test('ErrorOccurred wraps FinalReviewState correctly', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      await fsm.transition(const TargetLoaded());
      await fsm.transition(const ContentRead());
      await fsm.transition(const ListingConfirmed([]));
      expect(fsm.state, isA<FinalReviewState>());

      await fsm.transition(const ErrorOccurred('review failed'));

      expect((fsm.state as ErrorState).failedState, isA<FinalReviewState>());
    });

    test(
      'two consecutive automatic-retry failures leave the FSM in '
      'ErrorState, not looping a third time automatically',
      () async {
        final fsm = ApplicationFlowFsm();
        await fsm.transition(const TriggerPressed());
        expect(fsm.state, isA<ListeningState>());

        // First failure cycle: one automatic retry attempt, it fails too.
        await fsm.transition(
          ErrorOccurred('attempt 1 failed', retryAction: () async => false),
        );
        expect(fsm.state, isA<ErrorState>());

        // Caller decides to try again (a second failure cycle) — still
        // ends up back in ErrorState, not stuck in RetryingState and not
        // silently escaping to some other state.
        await fsm.transition(
          ErrorOccurred('attempt 2 failed', retryAction: () async => false),
        );
        expect(fsm.state, isA<ErrorState>());
        expect((fsm.state as ErrorState).message, 'attempt 2 failed');
      },
    );

    test(
      'a successful automatic retry returns to the failed state, not '
      'ErrorState',
      () async {
        final fsm = ApplicationFlowFsm();
        await fsm.transition(const TriggerPressed());
        expect(fsm.state, isA<ListeningState>());

        await fsm.transition(
          ErrorOccurred('transient failure', retryAction: () async => true),
        );

        expect(fsm.state, isA<ListeningState>());
      },
    );

    test('RetryRequested while in ErrorState returns to failedState', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const TriggerPressed());
      await fsm.transition(const VoiceCommandRecognized('x'));
      await fsm.transition(const IntentParsed());
      expect(fsm.state, isA<LoadingTargetState>());

      await fsm.transition(const ErrorOccurred('load failed'));
      expect(fsm.state, isA<ErrorState>());

      await fsm.transition(const RetryRequested());
      expect(fsm.state, isA<LoadingTargetState>());
    });

    test('RetryRequested outside ErrorState is a no-op', () async {
      final fsm = ApplicationFlowFsm();
      await fsm.transition(const RetryRequested());
      expect(fsm.state, isA<IdleState>());
    });
  });
}
