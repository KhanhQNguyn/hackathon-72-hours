import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';

import '../mocks/test_doubles.dart';

// Milestone 35 — full mocked run: real FSM + controller + gate logic, with
// scripted "speech" and the fake WebView/PDF layer.
void main() {
  group('milestone35 — end-to-end flow against mocks', () {
    test('Idle to Done: every saved value accepted, submitted once', () async {
      final h = FlowHarness(
        script: [
          'read this listing', // command
          'yes', // checkpoint 1: right listing
          'yes', 'yes', 'yes', // name, phone, email: use saved values
          'confirm', // checkpoint 2: submit
        ],
      );

      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.submitCalls, 1);
      expect(h.web.filled, {
        'n-name': 'Alex Nguyen',
        'n-phone': '0900000000',
        'n-email': 'alex@example.com',
      });
      expect(h.web.fileChooserNodes, ['n-cv']);
      // The saved CV cannot be given to a web form; the user re-picks it in
      // the page's own chooser, which is announced first.
      final spoken = h.tts.spoken;
      final announced = spoken.indexOf(FlowNarration('en').cvChooserAnnouncement);
      expect(announced, isNonNegative);
      expect(spoken.indexOf(FlowNarration('en').cvChosen('cv.pdf')), greaterThan(announced));
      expect(h.chooserWaits, 1);
      expect(h.controller.lastNarration, contains('submitted'));
    });

    test('narrates every step and the on-screen text mirrors it', () async {
      final h = FlowHarness(
        script: ['go', 'yes', 'yes', 'yes', 'yes', 'confirm'],
      );
      await h.controller.start();

      expect(h.tts.spoken.first, contains('Listening'));
      expect(h.tts.spoken.any((s) => s.contains('Here is the listing')), isTrue);
      expect(h.tts.spoken.any((s) => s.contains('application form')), isTrue);
      expect(h.tts.spoken.any((s) => s.contains('Review:')), isTrue);
      expect(h.controller.lastNarration, h.tts.spoken.last);
    });

    test('a new spoken value is read back and must be confirmed', () async {
      final h = FlowHarness(
        profile: null,
        script: [
          'go', 'yes',
          'Sam Tran', 'yes', // name: no saved value -> ask, confirm
          '0911', 'yes', // phone
          'sam@example.com', 'yes', // email
          'confirm',
        ],
      );
      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.web.filled['n-name'], 'Sam Tran');
      expect(h.web.filled['n-phone'], '0911');
      expect(h.web.fileChooserNodes, ['n-cv']);
    });

    test('rejecting a saved value asks for a replacement', () async {
      final h = FlowHarness(
        script: [
          'go', 'yes',
          'no', 'Sam Tran', 'yes', // name: reject saved, give new, confirm
          'yes', 'yes',
          'confirm',
        ],
      );
      await h.controller.start();

      expect(h.web.filled['n-name'], 'Sam Tran');
      expect(h.fsm.state, isA<DoneState>());
    });

    test('final review: "edit phone" re-collects only that field', () async {
      final h = FlowHarness(
        script: [
          'go', 'yes',
          'yes', 'yes', 'yes',
          'edit phone', // from Final Review -> EditingField(n-phone)
          '0911111111', 'yes',
          'confirm',
        ],
      );
      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.web.filled['n-phone'], '0911111111');
      expect(h.web.filled['n-name'], 'Alex Nguyen', reason: 'others untouched');
      expect(h.submitCalls, 1);
    });

    test('an unrecognised reply at final review never submits', () async {
      final h = FlowHarness(
        script: ['go', 'yes', 'yes', 'yes', 'yes', 'hmm banana', 'confirm'],
      );
      await h.controller.start();

      expect(h.tts.spoken.any((s) => s.contains("didn't get that")), isTrue);
      expect(h.submitCalls, 1);
      expect(h.fsm.state, isA<DoneState>());
    });

    test('declining the listing stops before anything is filled', () async {
      final h = FlowHarness(script: ['go', 'no']);
      await h.controller.start();

      expect(h.fsm.state, isA<IdleState>());
      expect(h.web.filled, isEmpty);
      expect(h.submitCalls, 0);
    });

    test('no spoken command: ends in ErrorState, restartable', () async {
      final h = FlowHarness(script: const []);
      await h.controller.start();
      expect(h.fsm.state, isA<ErrorState>());
      expect(h.submitCalls, 0);

      // The button can start a fresh run from ErrorState.
      final h2 = FlowHarness(script: ['go', 'no']);
      await h2.fsm.transition(const ErrorOccurred('earlier failure'));
      await h2.controller.start();
      expect(h2.fsm.state, isA<IdleState>());
    });

    test('a fill that never sticks ends in ErrorState, no submit', () async {
      final h = FlowHarness(script: ['go', 'yes', 'yes', 'yes', 'yes']);
      h.web.failFills = true;
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.submitCalls, 0);
    });

    test('Vietnamese narration when the language pref is vi', () async {
      final h = FlowHarness(
        language: 'vi',
        script: ['đọc tin', 'có', 'có', 'có', 'có', 'xác nhận'],
      );
      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.tts.spoken.first, contains('Đang nghe'));
      expect(h.controller.lastNarration, contains('đã được nộp'));
    });
  });
}
