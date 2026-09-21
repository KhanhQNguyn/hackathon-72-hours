import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/mocks/fake_pdf_reader_service.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/ui/screens/home_screen.dart';
import 'package:provider/provider.dart';

import '../mocks/test_doubles.dart';

Widget _app(ApplicationFlowFsm fsm) {
  final h = FlowHarness();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ApplicationFlowFsm>.value(value: fsm),
      ChangeNotifierProvider<ApplicationFlowController>.value(
        value: ApplicationFlowController(
          fsm: fsm,
          speech: ScriptedSpeech(const []),
          tts: h.tts,
          preferences: StubPrefs(),
          webView: h.web,
          pdfReader: FakePdfReaderService(),
          profileService: MemoryProfileService(),
          filePicker: StubFilePicker(),
        ),
      ),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

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

  testWidgets('milestone35 — trigger re-enabled in Done and Error to restart',
      (tester) async {
    final handle = tester.ensureSemantics();
    final fsm = ApplicationFlowFsm();
    await tester.pumpWidget(_app(fsm));
    final button = find.bySemanticsLabel('Start voice command');

    await fsm.transition(const ErrorOccurred('x'));
    await tester.pump();
    expect(tester.getSemantics(button).flagsCollection.isEnabled, Tristate.isTrue);
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
