import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/mocks/fake_pdf_reader_service.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/services/applicant_profile_service.dart';
import 'package:job_access_assist/services/file_picker_service.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/ui/screens/home_screen.dart';
import 'package:job_access_assist/ui/screens/settings_screen.dart';
import 'package:provider/provider.dart';

import '../mocks/test_doubles.dart';

// Milestone 43 — the automated, code-level part. Flutter's built-in
// guideline checks approximate a subset of Google's Accessibility Scanner
// (labels, 48dp targets, contrast). They do NOT replace the manual TalkBack
// swipe-through on a real device, which this milestone also requires.

Widget _wrap(Widget screen, {String language = 'en'}) {
  final h = FlowHarness(language: language);
  final fsm = ApplicationFlowFsm();
  return MultiProvider(
    providers: [
      Provider<PreferencesService>.value(value: StubPrefs(language)),
      Provider<ApplicantProfileService>.value(value: MemoryProfileService()),
      Provider<FilePickerService>.value(value: StubFilePicker()),
      ChangeNotifierProvider<ApplicationFlowFsm>.value(value: fsm),
      ChangeNotifierProvider<ApplicationFlowController>.value(
        value: ApplicationFlowController(
          fsm: fsm,
          speech: ScriptedSpeech(const []),
          tts: h.tts,
          preferences: StubPrefs(language),
          webView: h.web,
          pdfReader: FakePdfReaderService(),
          profileService: MemoryProfileService(),
        ),
      ),
    ],
    child: MaterialApp(home: screen),
  );
}

void main() {
  for (final entry in {
    'home': () => const HomeScreen(),
    'settings': () => const SettingsScreen(),
  }.entries) {
    group('milestone43 — ${entry.key} screen guidelines', () {
      testWidgets('every tap target is labeled', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('tap targets are at least 48dp', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('text contrast meets the minimum', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(entry.value()));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    });
  }

  testWidgets('settings: language options are named in their own language', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('English'), findsOneWidget);
    expect(find.bySemanticsLabel('Tiếng Việt'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('settings: the profile fields and buttons are labeled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    for (final label in [
      'Full name',
      'Phone number',
      'Email',
      'Choose CV file',
      'Save profile',
    ]) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets, reason: label);
    }
    handle.dispose();
  });

  testWidgets('settings: labels switch to Vietnamese with the language pref', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const SettingsScreen(), language: 'vi'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Họ và tên')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Lưu hồ sơ')), findsWidgets);
    handle.dispose();
  });
}
