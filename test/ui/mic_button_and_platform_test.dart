import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/app.dart';
import 'package:job_access_assist/core/theme.dart';
import 'package:job_access_assist/models/voice_command_result.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/services/applicant_profile_service.dart';
import 'package:job_access_assist/services/file_picker_service.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/services/speech_service.dart';
import 'package:job_access_assist/ui/screens/home_screen.dart';
import 'package:job_access_assist/ui/screens/settings_screen.dart';
import 'package:provider/provider.dart';

import '../mocks/test_doubles.dart';

/// The first `listen()` blocks until [release] is called, so a test can
/// look at the UI while the microphone is "open".
class HoldingSpeech implements SpeechService {
  final Completer<VoiceCommandResult> _first = Completer();
  bool _used = false;

  void release() => _first.complete(
    const VoiceCommandResult(transcript: '', confidence: 0, alternatives: []),
  );

  @override
  Future<VoiceCommandResult> listen() {
    if (!_used) {
      _used = true;
      return _first.future;
    }
    return Future.value(
      const VoiceCommandResult(transcript: '', confidence: 0, alternatives: []),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _home(FlowHarness h) => MultiProvider(
  providers: [
    ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
    ChangeNotifierProvider<ApplicationFlowController>.value(
      value: h.controller,
    ),
  ],
  child: const MaterialApp(home: HomeScreen()),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump();
  }
}

void main() {
  group('mic button — three visibly different states', () {
    testWidgets('ready: mic icon, base label, enabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_home(FlowHarness()));

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).height, 72);
      final node = tester.getSemantics(find.bySemanticsLabel('Start voice command'));
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('listening: hearing icon and "Listening…" label', (tester) async {
      final handle = tester.ensureSemantics();
      final speech = HoldingSpeech();
      final h = FlowHarness(speech: speech);
      await tester.pumpWidget(_home(h));

      final run = h.controller.start();
      await _settle(tester);

      expect(find.byIcon(Icons.hearing), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.bySemanticsLabel('Listening…'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'cannot restart while listening');
      expect(
        button.style?.backgroundColor?.resolve({WidgetState.disabled}),
        AppTheme.listening,
      );

      speech.release();
      await _settle(tester);
      await run;

      // Back to a non-listening icon once the mic closes.
      expect(find.byIcon(Icons.hearing), findsNothing);
      handle.dispose();
    });

    testWidgets('unavailable: mic_off icon and the button is disabled', (tester) async {
      final handle = tester.ensureSemantics();
      final h = FlowHarness();
      await tester.pumpWidget(_home(h));

      await h.fsm.transition(const TriggerPressed()); // a run is "in progress"
      await tester.pump();

      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Working...'));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('labels are Vietnamese when the language pref is vi', (tester) async {
      final handle = tester.ensureSemantics();
      final h = FlowHarness(language: 'vi');
      await h.controller.refreshLanguage();
      await tester.pumpWidget(_home(h));

      expect(find.bySemanticsLabel('Bắt đầu ra lệnh bằng giọng nói'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget, reason: 'Settings button localized');
      handle.dispose();
    });
  });

  group('non-Android platforms get an explicit message', () {
    testWidgets('Windows shows the Android-only message, not the app', (tester) async {
      await tester.pumpWidget(const App(platform: TargetPlatform.windows));

      expect(
        find.text('This app is designed for Android — please run on an Android device.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    ]) {
      testWidgets('$platform is also refused', (tester) async {
        await tester.pumpWidget(App(platform: platform));
        expect(find.textContaining('designed for Android'), findsOneWidget);
      });
    }

    testWidgets('Android builds the normal app', (tester) async {
      await tester.pumpWidget(const App(platform: TargetPlatform.android));
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.textContaining('designed for Android'), findsNothing);
    });
  });

  group('settings — feedback after picking a CV', () {
    Widget wrap(String? pickedPath, {String language = 'en'}) {
      final h = FlowHarness(language: language);
      return MultiProvider(
        providers: [
          Provider<PreferencesService>.value(value: StubPrefs(language)),
          Provider<ApplicantProfileService>.value(value: MemoryProfileService()),
          Provider<FilePickerService>.value(value: StubFilePicker(pickedPath)),
          ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
          ChangeNotifierProvider<ApplicationFlowController>.value(
            value: h.controller,
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );
    }

    testWidgets('picking a file says it still has to be saved', (tester) async {
      await tester.pumpWidget(wrap('/x/cv.pdf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose CV file'));
      await tester.pumpAndSettle();

      expect(find.text('/x/cv.pdf'), findsOneWidget);
      expect(
        find.text('CV file selected. Press Save profile to keep it.'),
        findsOneWidget,
      );
    });

    testWidgets('the same feedback in Vietnamese', (tester) async {
      await tester.pumpWidget(wrap('/x/cv.pdf', language: 'vi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chọn tệp CV'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đã chọn file CV. Nhấn Lưu hồ sơ để giữ lại.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the picker shows no false "selected" message', (tester) async {
      await tester.pumpWidget(wrap(null));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose CV file'));
      await tester.pumpAndSettle();

      expect(
        find.text('CV file selected. Press Save profile to keep it.'),
        findsNothing,
      );
    });
  });
}
