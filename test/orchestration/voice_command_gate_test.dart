import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/models/voice_command_result.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/orchestration/voice_command_gate.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/services/speech_service.dart';
import 'package:job_access_assist/services/tts_service.dart';

class _Hang {}

class _FakeSpeech implements SpeechService {
  _FakeSpeech(this.results);
  final List<Object> results; // VoiceCommandResult or an exception to throw
  int calls = 0;

  @override
  Future<VoiceCommandResult> listen() async {
    final next = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (next is Exception) throw next;
    if (next is _Hang) return Completer<VoiceCommandResult>().future;
    return next as VoiceCommandResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTts implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePrefs implements PreferencesService {
  _FakePrefs(this.language);
  final String language;

  @override
  Future<String> getLanguagePref() async => language;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

VoiceCommandResult _r(String text, double confidence) => VoiceCommandResult(
  transcript: text,
  confidence: confidence,
  alternatives: [text],
);

Future<
  ({
    ApplicationFlowFsm fsm,
    _FakeSpeech speech,
    _FakeTts tts,
    VoiceCommandGate gate,
  })
>
_setup(List<Object> results, {String language = 'en'}) async {
  final fsm = ApplicationFlowFsm();
  await fsm.transition(const TriggerPressed());
  final speech = _FakeSpeech(results);
  final tts = _FakeTts();
  final gate = VoiceCommandGate(
    fsm: fsm,
    speech: speech,
    tts: tts,
    preferences: _FakePrefs(language),
  );
  return (fsm: fsm, speech: speech, tts: tts, gate: gate);
}

void main() {
  group('milestone29 — STT confidence gating', () {
    test(
      'confidence 0.4: stays Listening, re-prompts, never advances',
      () async {
        final s = await _setup([_r('read listing', 0.4), _Hang()]);
        // Second listen() never completes, so the gate is parked right
        // after the first rejection — the state we want to inspect.
        final running = s.gate.run();
        await Future<void>.delayed(Duration.zero);
        expect(s.tts.spoken, [repromptMessage('en')]);
        expect(s.fsm.state, isA<ListeningState>());
        expect(s.speech.calls, 2);
        running.ignore();
      },
    );

    test(
      'confidence 0.8: fires VoiceCommandRecognized -> ParsingIntent',
      () async {
        final s = await _setup([_r('read listing', 0.8)]);
        await s.gate.run();
        expect(s.fsm.state, isA<ParsingIntentState>());
        expect(s.tts.spoken, isEmpty);
      },
    );

    test('low then high confidence: re-prompts once, then advances', () async {
      final s = await _setup([_r('mumble', 0.3), _r('read listing', 0.9)]);
      await s.gate.run();
      expect(s.speech.calls, 2);
      expect(s.tts.spoken, [repromptMessage('en')]);
      expect(s.fsm.state, isA<ParsingIntentState>());
    });

    test('exactly at threshold (0.6) is accepted', () async {
      final s = await _setup([_r('read listing', 0.6)]);
      await s.gate.run();
      expect(s.fsm.state, isA<ParsingIntentState>());
    });

    test('empty transcript is rejected even with high confidence', () async {
      final s = await _setup([_r('', 1.0), _r('go', 0.9)]);
      await s.gate.run();
      expect(s.speech.calls, 2);
      expect(s.fsm.state, isA<ParsingIntentState>());
    });

    test('Vietnamese re-prompt used when language pref is vi', () async {
      final s = await _setup([_r('x', 0.1), _r('ok', 0.9)], language: 'vi');
      await s.gate.run();
      expect(s.tts.spoken.single, repromptMessage('vi'));
      expect(s.tts.spoken.single, contains('Xin lỗi'));
    });

    test('gives up with an ErrorState after maxAttempts rejections', () async {
      final s = await _setup([_r('x', 0.1)]);
      await s.gate.run();
      expect(s.speech.calls, 3);
      expect(s.fsm.state, isA<ErrorState>());
    });

    test('unavailable recognizer -> spoken message + ErrorState', () async {
      final s = await _setup([const SpeechUnavailableException('no mic')]);
      await s.gate.run();
      expect(s.fsm.state, isA<ErrorState>());
      expect(s.tts.spoken.single, speechUnavailableMessage('en'));
    });
  });
}
