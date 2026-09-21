import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/services/speech_service.dart';
import 'package:job_access_assist/services/tts_service.dart';
import 'package:job_access_assist/ui/screens/home_screen.dart';
import 'package:provider/provider.dart';

class _StubSpeech implements SpeechService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTts implements TtsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(ApplicationFlowFsm fsm) => MultiProvider(
  providers: [
    Provider<PreferencesService>(create: (_) => PreferencesService()),
    Provider<SpeechService>(create: (_) => _StubSpeech()),
    Provider<TtsService>(create: (_) => _StubTts()),
    ChangeNotifierProvider<ApplicationFlowFsm>.value(value: fsm),
  ],
  child: const MaterialApp(home: HomeScreen()),
);

void main() {
  testWidgets('milestone26 — status text follows the FSM state', (
    tester,
  ) async {
    final fsm = ApplicationFlowFsm();
    await tester.pumpWidget(_app(fsm));
    expect(find.text(narrationFor(const IdleState())), findsOneWidget);

    await fsm.transition(const TriggerPressed());
    await tester.pump();
    expect(find.text(narrationFor(const ListeningState())), findsOneWidget);
  });

  testWidgets('milestone26 — narration is still a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(ApplicationFlowFsm()));
    final node = tester.getSemantics(
      find.text(narrationFor(const IdleState())),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('milestone27 — trigger enabled in Idle, fires TriggerPressed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final fsm = ApplicationFlowFsm();
    await tester.pumpWidget(_app(fsm));

    final button = find.bySemanticsLabel('Start voice command');
    expect(
      tester.getSemantics(button).flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    handle.dispose();
  });

  testWidgets('milestone27 — trigger reported disabled outside Idle', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final fsm = ApplicationFlowFsm();
    await tester.pumpWidget(_app(fsm));
    await fsm.transition(const TriggerPressed());
    await tester.pump();

    final button = find.bySemanticsLabel('Start voice command');
    expect(
      tester.getSemantics(button).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
    handle.dispose();
  });
}
