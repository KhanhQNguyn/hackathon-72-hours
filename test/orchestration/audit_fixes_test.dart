import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/models/voice_command_result.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/orchestration/voice_command_gate.dart';
import 'package:job_access_assist/services/speech_service.dart';

import '../mocks/test_doubles.dart';

// Fixes from docs/intent/audit-2026-09-22.md, each pinned by a test.

class _OrderedSpeech implements SpeechService {
  _OrderedSpeech(this.events, this.results);
  final List<String> events;
  final List<VoiceCommandResult> results;

  @override
  Future<VoiceCommandResult> listen() async {
    events.add('listen');
    return results.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OrderedTts extends RecordingTts {
  _OrderedTts(this.events);
  final List<String> events;

  @override
  Future<void> speak(String text) async {
    events.add('tts:$text');
    await super.speak(text);
  }
}

class _UnavailableSpeech implements SpeechService {
  @override
  Future<VoiceCommandResult> listen() async =>
      throw const SpeechUnavailableException('no mic');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VoiceCommandResult _heard(String t) =>
    VoiceCommandResult(transcript: t, confidence: 0.9, alternatives: [t]);

const _silence = VoiceCommandResult(
  transcript: '',
  confidence: 0.0,
  alternatives: [],
);

VoiceCommandGate _gate(
  List<String> events,
  List<VoiceCommandResult> results, {
  bool cues = true,
  String language = 'en',
}) {
  final tts = _OrderedTts(events);
  return VoiceCommandGate(
    fsm: ApplicationFlowFsm(),
    speech: _OrderedSpeech(events, List.of(results)),
    tts: tts,
    preferences: StubPrefs(language),
    playCues: cues,
    onListeningChanged: (l) => events.add('mic:$l'),
    maxAttempts: 1,
  );
}

void main() {
  group('mic UX — one signal drives the visual state and the audio cues', () {
    test('mic opens, start cue plays, THEN the recognizer listens', () async {
      final events = <String>[];
      final gate = _gate(events, [_heard('hello')]);
      await gate.listenConfident();

      expect(events, [
        'mic:true',
        'tts:Listening',
        'listen',
        'mic:false',
        'tts:Got it',
      ]);
    });

    test('silence: no stop cue, the spoken re-prompt is the stop cue', () async {
      final events = <String>[];
      final gate = _gate(events, [_silence]);
      final result = await gate.listenConfident();

      expect(result, isNull);
      expect(events, [
        'mic:true',
        'tts:Listening',
        'listen',
        'mic:false',
        'tts:${repromptMessage('en')}',
      ]);
      expect(events.contains('tts:Got it'), isFalse);
    });

    test('cues are opt-in: plain gate use stays silent', () async {
      final events = <String>[];
      final gate = _gate(events, [_heard('hi')], cues: false);
      await gate.listenConfident();
      expect(events, ['mic:true', 'listen', 'mic:false']);
    });

    test('Vietnamese cues follow the language preference', () async {
      final events = <String>[];
      final gate = _gate(events, [_heard('xin chào')], language: 'vi');
      await gate.listenConfident();
      expect(events, contains('tts:Đang nghe'));
      expect(events, contains('tts:Đã nghe rõ'));
    });

    test('the mic is reported closed even if the recognizer is unavailable', () async {
      final events = <String>[];
      final gate = VoiceCommandGate(
        fsm: ApplicationFlowFsm(),
        speech: _UnavailableSpeech(),
        tts: _OrderedTts(events),
        preferences: StubPrefs(),
        onListeningChanged: (l) => events.add('mic:$l'),
        playCues: true,
      );
      expect(await gate.listenConfident(), isNull);
      expect(gate.speechUnavailable, isTrue);
      // closed BEFORE the spoken explanation, not after
      expect(events.indexOf('mic:false'), lessThan(events.indexWhere((e) => e.contains('unavailable'))));
    });

    test('controller.isListening is true during a run and false after', () async {
      final h = FlowHarness(script: ['go', 'no']);
      final seen = <bool>[];
      h.controller.addListener(() => seen.add(h.controller.isListening));
      await h.controller.start();

      expect(seen, contains(true));
      expect(h.controller.isListening, isFalse);
    });

    test('a failed run message is localized (no English inside Vietnamese)', () async {
      final h = FlowHarness(language: 'vi', script: const []);
      await h.controller.start();

      final failure = h.tts.spoken.firstWhere((s) => s.startsWith('Đã xảy ra lỗi'));
      expect(failure, contains(FlowNarration('vi').errVoice));
      expect(h.tts.spoken.any((s) => s.contains('Something went wrong')), isFalse);
      expect(h.tts.spoken.any((s) => s.contains("Couldn't")), isFalse);
    });
  });

  group('audit 1.5 — CAPTCHA', () {
    // A CAPTCHA is present on every check: after reading the page, and again
    // just before submit. So two "continue"s are needed.
    final flow = [
      'go',
      'continue', // after the initial read
      'yes',
      'yes', 'yes', 'yes',
      'confirm',
      'continue', // before submit
    ];

    test('clicking the audio button does NOT count as solved', () async {
      final h = FlowHarness(script: flow);
      h.web
        ..captchaPresent = true
        ..audioButtonFound = true;
      await h.controller.start();

      expect(h.tts.spoken, contains(FlowNarration('en').captchaAudioOpened));
      expect(h.web.captchaChecks, 2);
      expect(h.fsm.state, isA<DoneState>());
    });

    test('without "continue" the flow stops instead of assuming it is solved', () async {
      final h = FlowHarness(script: ['go']); // never says continue
      h.web
        ..captchaPresent = true
        ..audioButtonFound = true;
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.web.filled, isEmpty);
    });

    test('no audio option: spoken hand-off, then waits for continue', () async {
      final h = FlowHarness(script: flow);
      h.web.captchaPresent = true;
      await h.controller.start();

      expect(h.tts.spoken, contains(FlowNarration('en').captchaHandOff));
      expect(h.fsm.state, isA<DoneState>());
    });

    test('the Vietnamese hand-off is the verbatim string', () async {
      final h = FlowHarness(
        language: 'vi',
        script: ['go', 'tiếp tục', 'có', 'có', 'có', 'có', 'xác nhận', 'tiếp tục'],
      );
      h.web.captchaPresent = true;
      await h.controller.start();

      expect(h.tts.spoken, contains(captchaHandOffVi));
    });
  });

  group('audit 1.4b — live file upload', () {
    const flow = ['go', 'yes', 'yes', 'yes', 'yes', 'confirm'];

    test('the chooser is announced BEFORE it is opened', () async {
      final h = FlowHarness(script: flow);
      List<String>? spokenWhenOpened;
      h.web.onTriggerFileChooser = () => spokenWhenOpened = List.of(h.tts.spoken);
      await h.controller.start();

      expect(spokenWhenOpened, isNotNull);
      expect(
        spokenWhenOpened,
        contains(FlowNarration('en').cvChooserAnnouncement),
      );
    });

    test('nothing attached: says so, does not claim success, run continues', () async {
      final h = FlowHarness(script: flow);
      h.web.attachedFileName = null;
      await h.controller.start();

      expect(h.tts.spoken, contains(FlowNarration('en').cvNotAttached));
      expect(h.tts.spoken.any((s) => s.startsWith('CV file selected')), isFalse);
      expect(h.fsm.state, isA<DoneState>());
    });

    test('chooser could not open: skipped without waiting', () async {
      final h = FlowHarness(script: flow);
      h.web.chooserOpens = false;
      await h.controller.start();

      expect(h.tts.spoken, contains(FlowNarration('en').cvNone));
      expect(h.chooserWaits, 0);
      expect(h.fsm.state, isA<DoneState>());
    });

    test('the announcement says the CV must be chosen again', () {
      expect(
        FlowNarration('en').cvChooserAnnouncement.toLowerCase(),
        contains('again'),
      );
      expect(FlowNarration('vi').cvChooserAnnouncement, contains('chọn lại'));
    });
  });

  group('audit 1.6 — retry by voice', () {
    test('a failed submit resumes at the final review', () async {
      final h = FlowHarness(
        wireSubmitHook: true,
        script: ['go', 'yes', 'yes', 'yes', 'yes', 'confirm', 'retry', 'confirm'],
      );
      h.web.failClicks = 1;
      await h.controller.start();

      expect(h.web.clicked, ['n-submit', 'n-submit']);
      expect(h.fsm.state, isA<DoneState>());
      expect(h.tts.spoken, contains(FlowNarration('en').retryPrompt));
    });

    test('any other failure starts a fresh run when the user says retry', () async {
      final h = FlowHarness(
        script: [
          'go', 'yes', 'yes', // run 1: name saved, fill fails twice
          'retry',
          'go', 'yes', 'yes', 'yes', 'yes', 'confirm', // run 2 succeeds
        ],
      );
      h.web.failFillTimes = 2; // the fill and its one automatic retry
      await h.controller.start();

      expect(h.fsm.state, isA<DoneState>());
      expect(h.submitCalls, 1);
    });

    test('silence after the retry prompt leaves the error in place', () async {
      final h = FlowHarness(script: const []);
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.tts.spoken, contains(FlowNarration('en').retryPrompt));
    });

    test('an unusable microphone does not offer "say retry"', () async {
      final h = FlowHarness(speech: _UnavailableSpeech());
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.tts.spoken.contains(FlowNarration('en').retryPrompt), isFalse);
    });

    test('voice retries are capped', () async {
      final h = FlowHarness(
        maxVoiceRetries: 1,
        script: [
          'go', 'yes', 'yes', 'retry', // run 1 fails, retried once
          'go', 'yes', 'yes', 'retry', // run 2 fails again: not retried
          'go', 'yes', 'yes', 'yes', 'yes', 'confirm',
        ],
      );
      h.web.failFillTimes = 4;
      await h.controller.start();

      expect(h.fsm.state, isA<ErrorState>());
      expect(h.submitCalls, 0);
    });

    test('error messages carry a Vietnamese sentence in Vietnamese mode', () {
      final n = FlowNarration('vi');
      for (final message in [
        n.errPageLoad,
        n.errAiUnavailable,
        n.errNoRequest,
        n.errVoice,
        n.errSpeechUnavailable,
        n.errNoListingReply,
        n.errNoReviewReply,
        n.errCaptcha,
        n.errNoAnswer('x'),
        n.errFill('x'),
        n.errSubmitNoButton,
        n.errSubmitUnsure,
        n.errSubmitClick,
        n.errUnexpected,
      ]) {
        expect(message, isNot(matches(RegExp(r"^[A-Za-z' ,.]+$"))), reason: message);
      }
    });
  });

  group('audit 1.8 — real-page robustness', () {
    test('a busy page is waited for, but not forever', () async {
      final h = FlowHarness(
        settleDelay: const Duration(milliseconds: 60),
        settleMaxWait: const Duration(milliseconds: 400),
        script: ['go', 'no'],
      );
      // The page keeps mutating: quiet is never reached, the cap must end it.
      final ticker = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => h.web.notifyLoadStop(),
      );
      final watch = Stopwatch()..start();
      await h.controller.start();
      ticker.cancel();

      expect(h.fsm.state, isA<IdleState>());
      expect(watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 380)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('a quiet page is read after just the settle delay', () async {
      final h = FlowHarness(
        settleDelay: const Duration(milliseconds: 80),
        script: ['go', 'no'],
      );
      final watch = Stopwatch()..start();
      await h.controller.start();

      expect(watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 70)));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('unrelated page inputs are not asked about', () async {
      final h = FlowHarness(script: ['go', 'yes', 'yes', 'confirm']);
      h.web.snapshotOverride = const DomSnapshot(
        images: [],
        searchCandidates: [
          DomFormField(elementId: 'srch', tag: 'input', type: 'search'),
        ],
        submitCandidates: [
          DomFormField(elementId: 'go', tag: 'button', type: 'submit'),
        ],
        labeledFields: [
          DomFormField(
            elementId: 'srch',
            tag: 'input',
            type: 'search',
            resolvedLabel: 'Search jobs',
          ),
          DomFormField(elementId: 'hid', tag: 'input', type: 'hidden'),
          DomFormField(
            elementId: 'news',
            tag: 'input',
            type: 'checkbox',
            resolvedLabel: 'Subscribe',
          ),
          DomFormField(
            elementId: 'n-name',
            tag: 'input',
            type: 'text',
            resolvedLabel: 'Full name',
          ),
          DomFormField(
            elementId: 'btn',
            tag: 'input',
            type: 'button',
            resolvedLabel: 'Apply',
          ),
        ],
        visibleText: 'A listing',
        truncated: false,
      );
      await h.controller.start();

      expect(h.web.filled.keys, ['n-name']);
      expect(h.fsm.state, isA<DoneState>());
    });
  });
}
