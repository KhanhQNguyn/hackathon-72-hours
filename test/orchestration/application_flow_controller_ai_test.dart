import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/models/element_match_result.dart';
import 'package:job_access_assist/models/openai_results.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';

import '../mocks/test_doubles.dart';

// Milestones 36-41 and 44 wired into the flow: intent parsing, image
// transcription, listing summary, PDF structure, element disambiguation,
// fuzzy matching and the real (gated) submit click.
void main() {
  group('milestone36 — intent parsing in the flow', () {
    test('the accepted transcript and its n-best go to the parser', () async {
      final ai = FakeOpenAi();
      final h = FlowHarness(
        ai: ai,
        script: ['apply to this job', 'yes', 'yes', 'yes', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(ai.lastTranscript, 'apply to this job');
      expect(ai.lastAlternatives, contains('apply to this job alt'));
      expect(h.fsm.state, isA<DoneState>());
    });

    test('an unrecognized intent re-prompts, then continues', () async {
      final ai = FakeOpenAi()
        ..intents = [
          const IntentResult(
            intentType: IntentType.unrecognized,
            confidence: 0.2,
          ),
          const IntentResult(
            intentType: IntentType.fillAndSubmit,
            confidence: 0.9,
          ),
        ];
      final h = FlowHarness(
        ai: ai,
        script: ['uh', 'apply', 'yes', 'yes', 'yes', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(ai.intentCalls, 2);
      expect(h.tts.spoken.where((s) => s == repromptMessage('en')), hasLength(1));
      expect(h.fsm.state, isA<DoneState>());
    });

    test('three unrecognized commands end in ErrorState', () async {
      final ai = FakeOpenAi()
        ..intents = [
          const IntentResult(
            intentType: IntentType.unrecognized,
            confidence: 0.1,
          ),
        ];
      final h = FlowHarness(ai: ai, script: ['a', 'b', 'c']);
      await h.controller.start();

      expect(ai.intentCalls, 3);
      expect(h.fsm.state, isA<ErrorState>());
      expect(h.web.filled, isEmpty);
    });

    test('"take me to X" is acknowledged, not acted on', () async {
      final ai = FakeOpenAi()
        ..intents = [
          const IntentResult(
            intentType: IntentType.navigateToElement,
            targetDescription: 'search bar',
            confidence: 0.9,
          ),
        ];
      final h = FlowHarness(ai: ai, script: ['take me to the search bar']);
      await h.controller.start();

      expect(h.fsm.state, isA<IdleState>());
      expect(h.tts.spoken, contains(FlowNarration('en').navigateUnsupported));
      expect(h.web.filled, isEmpty);
    });

    test('a failed parse is retried through the FSM, then succeeds', () async {
      final ai = FakeOpenAi()..failIntentTimes = 1;
      final h = FlowHarness(
        ai: ai,
        script: ['apply', 'yes', 'yes', 'yes', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(ai.intentCalls, 2);
      expect(h.fsm.state, isA<DoneState>());
    });

    test('with no AI, any accepted command applies (previous behaviour)', () async {
      final h = FlowHarness(script: ['whatever', 'yes', 'yes', 'yes', 'yes', 'confirm']);
      await h.controller.start();
      expect(h.fsm.state, isA<DoneState>());
    });
  });

  group('milestones 37/38/40 — reading the listing and the form', () {
    final flow = ['go', 'yes', 'yes', 'yes', 'yes', 'confirm'];

    test('images without alt text are transcribed and read aloud', () async {
      final ai = FakeOpenAi();
      final h = FlowHarness(ai: ai, script: flow);
      await h.controller.start();

      // The canned page has 3 images; 2 lack meaningful alt text.
      expect(ai.imageBase64Calls, hasLength(2));
      expect(
        h.tts.spoken,
        contains(FlowNarration('en').imageTranscript('Job posting text from the picture')),
      );
    });

    test('low-confidence or empty transcriptions are not read out', () async {
      final ai = FakeOpenAi()
        ..image = const ImageTranscription(text: 'blurry', confidence: 0.2);
      final h = FlowHarness(ai: ai, script: flow);
      await h.controller.start();
      expect(h.tts.spoken.any((s) => s.contains('An image on the page says')), isFalse);
    });

    test('a confident AI summary replaces the raw page text', () async {
      final ai = FakeOpenAi()
        ..summary = ListingSummary(listing: sampleListing, confidence: 0.9);
      final h = FlowHarness(ai: ai, script: flow);
      await h.controller.start();

      expect(h.tts.spoken.any((s) => s.contains('Flutter Developer at Example Co.')), isTrue);
      expect(h.tts.spoken.any((s) => s.contains('Here is the listing')), isFalse);
    });

    test('a low-confidence summary falls back to the raw text', () async {
      final ai = FakeOpenAi()
        ..summary = ListingSummary(listing: sampleListing, confidence: 0.2);
      final h = FlowHarness(ai: ai, script: flow);
      await h.controller.start();
      expect(h.tts.spoken.any((s) => s.contains('Here is the listing')), isTrue);
    });

    test('the form is read section by section when AI structured it', () async {
      final ai = FakeOpenAi()
        ..pdf = const PdfStructure(
          sections: [
            PdfSection(heading: 'Personal details', body: 'Name and email'),
            PdfSection(heading: 'Attachments', body: 'Attach your CV'),
          ],
          inferredFields: [],
        );
      final h = FlowHarness(ai: ai, script: flow);
      await h.controller.start();

      expect(h.tts.spoken, contains('Personal details. Name and email'));
      expect(h.tts.spoken, contains('Attachments. Attach your CV'));
      expect(h.tts.spoken.any((s) => s.contains('The application form says')), isFalse);
    });

    test('without a structure the raw form text is read', () async {
      final h = FlowHarness(ai: FakeOpenAi(), script: flow);
      await h.controller.start();
      expect(h.tts.spoken.any((s) => s.contains('The application form says')), isTrue);
    });
  });

  group('milestones 39/41 — matching a spoken field name', () {
    final upToReview = ['go', 'yes', 'yes', 'yes', 'yes'];

    test('an ambiguous match asks which field was meant', () async {
      final ai = FakeOpenAi()
        ..match = const ElementMatchResult(
          elementId: 'n-name',
          confidence: 0.4,
          reasoning: 'two possible',
          alternativeElementIds: ['n-email'],
        );
      final h = FlowHarness(
        ai: ai,
        script: [
          ...upToReview,
          'edit banana', // no fuzzy/keyword match -> AI, low confidence
          'email', // the user disambiguates
          'new@example.com', 'yes',
          'confirm',
        ],
      );
      await h.controller.start();

      expect(ai.matchTargets, ['banana']);
      expect(
        h.tts.spoken,
        contains(FlowNarration('en').disambiguate(['Full name', 'Email'])),
      );
      expect(h.web.filled['n-email'], 'new@example.com');
      expect(h.fsm.state, isA<DoneState>());
    });

    test('a confident AI match is used without asking', () async {
      final ai = FakeOpenAi()
        ..match = const ElementMatchResult(
          elementId: 'n-phone',
          confidence: 0.9,
          reasoning: 'clear',
        );
      final h = FlowHarness(
        ai: ai,
        script: [...upToReview, 'edit banana', '0911', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(h.web.filled['n-phone'], '0911');
      expect(h.tts.spoken.any((s) => s.contains('Which one did you mean')), isFalse);
    });

    test('fuzzy matching resolves a small mis-hearing without any AI call', () async {
      final ai = FakeOpenAi();
      final h = FlowHarness(
        ai: ai,
        script: [...upToReview, 'edit emails', 'a@b.com', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(ai.matchTargets, isEmpty);
      expect(h.web.filled['n-email'], 'a@b.com');
    });

    test('no match and no AI: says so and stays in review', () async {
      final h = FlowHarness(
        script: [...upToReview, 'edit banana', 'confirm'],
      );
      await h.controller.start();

      expect(h.tts.spoken, contains(FlowNarration('en').noSuchField('banana')));
      expect(h.fsm.state, isA<DoneState>());
    });
  });

  group('milestone44 — the real submit', () {
    final flow = ['go', 'yes', 'yes', 'yes', 'yes', 'confirm'];

    test('the FSM-gated submit clicks the page submit button once', () async {
      final h = FlowHarness(wireSubmitHook: true, script: flow);
      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.web.clicked, ['n-submit']);
    });

    test('nothing is clicked before the user confirms at final review', () async {
      final h = FlowHarness(
        wireSubmitHook: true,
        script: ['go', 'yes', 'yes', 'yes', 'yes'], // never says confirm
      );
      await h.controller.start();

      expect(h.web.clicked, isEmpty);
      expect(h.fsm.state, isA<ErrorState>());
    });

    test('a failed click ends in ErrorState, never Done', () async {
      final h = FlowHarness(wireSubmitHook: true, script: flow);
      h.web.clickSucceeds = false;
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.tts.spoken.any((s) => s.contains('could not be clicked')), isTrue);
    });

    const s1 = DomFormField(
      elementId: 's1',
      tag: 'button',
      role: 'submit',
      heuristicScore: 9,
    );
    const s2 = DomFormField(
      elementId: 's2',
      tag: 'button',
      role: 'submit',
      heuristicScore: 4,
    );
    const s3 = DomFormField(
      elementId: 's3',
      tag: 'button',
      role: 'submit',
      heuristicScore: 9,
    );

    test('no submit button on the page throws', () async {
      final h = FlowHarness();
      h.web.snapshotOverride = snapshotWithSubmit(const []);
      await expectLater(h.controller.submitApplication(), throwsA(isA<FlowFailure>()));
      expect(h.web.clicked, isEmpty);
    });

    test('a clearly best candidate is clicked without AI', () async {
      final h = FlowHarness();
      h.web.snapshotOverride = snapshotWithSubmit(const [s1, s2]);
      await h.controller.submitApplication();
      expect(h.web.clicked, ['s1']);
    });

    test('tied candidates and no AI: refuses to guess', () async {
      final h = FlowHarness();
      h.web.snapshotOverride = snapshotWithSubmit(const [s1, s3]);
      await expectLater(h.controller.submitApplication(), throwsA(isA<FlowFailure>()));
      expect(h.web.clicked, isEmpty);
    });

    test('tied candidates: a confident AI pick is clicked', () async {
      final ai = FakeOpenAi()
        ..match = const ElementMatchResult(
          elementId: 's3',
          confidence: 0.9,
          reasoning: 'labelled submit',
        );
      final h = FlowHarness(ai: ai);
      h.web.snapshotOverride = snapshotWithSubmit(const [s1, s3]);
      await h.controller.submitApplication();
      expect(h.web.clicked, ['s3']);
    });

    test('tied candidates: an unsure AI means no click', () async {
      final ai = FakeOpenAi()
        ..match = const ElementMatchResult(
          elementId: 's3',
          confidence: 0.4,
          reasoning: 'unsure',
          alternativeElementIds: ['s1'],
        );
      final h = FlowHarness(ai: ai);
      h.web.snapshotOverride = snapshotWithSubmit(const [s1, s3]);
      await expectLater(h.controller.submitApplication(), throwsA(isA<FlowFailure>()));
      expect(h.web.clicked, isEmpty);
    });
  });
}
