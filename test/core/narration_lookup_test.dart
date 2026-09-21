import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/models/job_listing.dart';
import 'package:job_access_assist/orchestration/application_flow_state.dart';

// Milestone 42 — every narrated state has an English and a Vietnamese
// line, and the two strings fixed by other documents are verbatim.
void main() {
  final states = <String, ApplicationFlowState>{
    'Idle': const IdleState(),
    'Listening': const ListeningState(),
    'ParsingIntent': const ParsingIntentState(),
    'LoadingTarget': const LoadingTargetState(),
    'ReadingContent': const ReadingContentState(),
    'AwaitingUserAction': const AwaitingUserActionState(),
    'FillingForm': const FillingFormState('Email', []),
    'FinalReview': const FinalReviewState(),
    'EditingField': const EditingFieldState('Email'),
    'AwaitingSubmitConfirmation': const AwaitingSubmitConfirmationState(),
    'Done': const DoneState(),
    'Retrying': const RetryingState(),
    'Error': const ErrorState(
      failedState: LoadingTargetState(),
      message: 'boom',
    ),
    'CaptchaPending': const CaptchaPendingState(
      interruptedState: ReadingContentState(),
    ),
  };

  group('milestone42 — narration script', () {
    for (final entry in states.entries) {
      test('${entry.key} has distinct, non-empty EN and VI text', () {
        final en = narrationFor(entry.value, language: 'en');
        final vi = narrationFor(entry.value, language: 'vi');
        expect(en.trim(), isNotEmpty);
        expect(vi.trim(), isNotEmpty);
        expect(vi, isNot(en));
        expect(en, isNot('Working...'), reason: 'must not hit the fallback');
      });
    }

    test('the CAPTCHA hand-off is verbatim from 01-intent.md', () {
      expect(
        narrationFor(states['CaptchaPending']!, language: 'vi'),
        "Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé",
      );
      expect(captchaHandOffVi, contains('tiếp tục'));
    });

    test('the retry line is verbatim from 02-spec.md', () {
      expect(
        narrationFor(const RetryingState(), language: 'en'),
        "that didn't load as expected, retrying...",
      );
      expect(FlowNarration('en').pageLoadFailed, pageRetryEn);
    });

    test('the STT re-prompt uses the milestone 29 wording in both languages', () {
      expect(repromptMessage('en'), "Sorry, I didn't catch that, could you repeat?");
      expect(
        repromptMessage('vi'),
        'Xin lỗi, tôi chưa nghe rõ, bạn nói lại được không?',
      );
    });

    test('templates carry their parameters in both languages', () {
      for (final lang in ['en', 'vi']) {
        final n = FlowNarration(lang);
        expect(n.fillingField('Email'), contains('Email'));
        expect(n.fieldNotFound('fax'), contains('fax'));
        expect(n.offerSaved('Phone', '0900'), allOf(contains('Phone'), contains('0900')));
        expect(n.confirmValue('Name', 'Alex'), allOf(contains('Name'), contains('Alex')));
        expect(n.finalReview('Name: Alex'), contains('Name: Alex'));
        expect(n.cvChosen('cv.pdf'), contains('cv.pdf'));
        expect(n.disambiguate(['A', 'B']), allOf(contains("'A'"), contains("'B'")));
      }
      expect(
        FlowNarration('en').fieldNotFound('fax'),
        "This form doesn't seem to have a field for fax — skipping it",
      );
    });

    test('an AI-extracted listing is spoken title/company first, in both languages', () {
      const listing = JobListing(
        title: 'Dev',
        company: 'Acme',
        requirements: 'Flutter',
        howToApply: 'Apply online',
      );
      expect(FlowNarration('en').listingFromAi(listing), startsWith('Dev at Acme.'));
      expect(FlowNarration('vi').listingFromAi(listing), startsWith('Dev tại Acme.'));
    });

    test('every plain line exists in both languages', () {
      final lines = <String Function(FlowNarration)>[
        (n) => n.idlePrompt,
        (n) => n.commandPrompt,
        (n) => n.parsingIntent,
        (n) => n.loadingPage,
        (n) => n.readingPage,
        (n) => n.confirmListing,
        (n) => n.listingDeclined,
        (n) => n.readingForm,
        (n) => n.pdfFailed,
        (n) => n.chooseFormPdf,
        (n) => n.noFormPdf,
        (n) => n.cvNone,
        (n) => n.reviewHeading,
        (n) => n.didNotUnderstand,
        (n) => n.submitting,
        (n) => n.done,
        (n) => n.navigateUnsupported,
        (n) => n.captchaAudioOpened,
      ];
      for (final line in lines) {
        final en = line(FlowNarration('en'));
        final vi = line(FlowNarration('vi'));
        expect(en.trim(), isNotEmpty);
        expect(vi.trim(), isNotEmpty);
        expect(vi, isNot(en));
      }
    });
  });
}
