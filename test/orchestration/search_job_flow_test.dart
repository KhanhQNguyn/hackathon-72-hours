import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/models/openai_results.dart';
import 'package:job_access_assist/orchestration/application_flow_state.dart';

import '../mocks/test_doubles.dart';

/// Real-target demo flow (VietnamWorks, single happy path) — exercises the
/// search_job intent end-to-end against the mocked WebView/AI stack:
/// search bar -> results reading + spoken-reply matching -> job detail ->
/// apply click -> per-field loop (reusing the saved profile) -> final
/// review -> submit with success verification (item F).
void main() {
  group('search_job flow — real-target demo path (mocked)', () {
    test('happy path: search, pick a result, apply, submit, verify success', () async {
      final harness = FlowHarness(
        wireSubmitHook: true,
        ai: FakeOpenAi()
          ..intents = [
            const IntentResult(
              intentType: IntentType.searchJob,
              targetDescription: 'software engineer',
              confidence: 0.9,
            ),
          ],
        script: [
          'I want to find software engineer job on VietnamWorks',
          'I choose Automation and Smart Manufacturing Software Engineer '
              'in Wistron NeWeb Corporation (WNC) in Hà Nam',
          'yes', // confirm apply
          'yes', // name: use saved value
          'yes', // phone: use saved value
          'yes', // email: use saved value
          'yes', // final review: confirm submit
        ],
      );

      await harness.controller.start();

      expect(harness.fsm.state, isA<DoneState>());
      expect(harness.controller.lastNarration, harness.controller.language == 'en'
          ? 'Your application has been submitted.'
          : isNotEmpty);

      // Searched, then clicked the search-submit button.
      expect(harness.web.filled['n-search'], 'software engineer');
      expect(harness.web.clicked, contains('n-search-submit'));

      // Matched the second (Wistron NeWeb) card, not the first.
      expect(harness.web.clicked, contains('n-card-1'));
      expect(harness.web.clicked, isNot(contains('n-card-0')));

      // Clicked "apply" then the real submit button.
      expect(harness.web.clicked, contains('n-submit'));

      // Field loop used the saved profile.
      expect(harness.web.filled['n-name'], 'Alex Nguyen');
      expect(harness.web.filled['n-phone'], '0900000000');
      expect(harness.web.filled['n-email'], 'alex@example.com');
    });

    test('no matching result: re-prompts, then fails after 3 tries', () async {
      final harness = FlowHarness(
        ai: FakeOpenAi()
          ..intents = [
            const IntentResult(
              intentType: IntentType.searchJob,
              targetDescription: 'software engineer',
              confidence: 0.9,
            ),
          ],
        script: [
          'I want to find software engineer job on VietnamWorks',
          'something completely unrelated',
          'something completely unrelated',
          'something completely unrelated',
        ],
      );

      await harness.controller.start();

      expect(harness.fsm.state, isA<ErrorState>());
      expect(harness.web.clicked, isNot(contains('n-card-0')));
      expect(harness.web.clicked, isNot(contains('n-card-1')));
    });

    test('submit succeeds but no success signal detected: reports unconfirmed, does not claim done', () async {
      final harness = FlowHarness(
        wireSubmitHook: true,
        ai: FakeOpenAi()
          ..intents = [
            const IntentResult(
              intentType: IntentType.searchJob,
              targetDescription: 'software engineer',
              confidence: 0.9,
            ),
          ],
        script: [
          'I want to find software engineer job on VietnamWorks',
          'I choose Wistron NeWeb Corporation software engineer Hà Nam',
          'yes',
          'yes',
          'yes',
          'yes',
          'yes',
        ],
      );
      harness.web.detectApplySuccessOverride = false;

      await harness.controller.start();

      expect(harness.fsm.state, isA<ErrorState>());
      final error = harness.fsm.state as ErrorState;
      expect(error.message, isNot(contains('submitted')));
      // The click itself still happened — only the confirmation is missing.
      expect(harness.web.clicked, contains('n-submit'));
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
