import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/services/applicant_profile_service.dart';
import 'package:job_access_assist/services/file_picker_service.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/ui/screens/home_screen.dart';
import 'package:job_access_assist/ui/screens/settings_screen.dart';
import 'package:provider/provider.dart';

import '../mocks/test_doubles.dart';

// docs/theme/DESIGN.md acceptance criterion 3: "Font scaling to 200% causes
// vertical reflow and scrolling, never clipping or horizontal truncation."
// A RenderFlex overflow during layout is reported via FlutterError, which
// testWidgets treats as a test failure — so a clean pump at 2x is the
// regression guard.

Widget _scaled(Widget screen, {double scale = 2.0}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: screen,
);

void main() {
  testWidgets('home screen at 200% text scale: no overflow, idle', (tester) async {
    final h = FlowHarness();
    await tester.pumpWidget(
      _scaled(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
            ChangeNotifierProvider<ApplicationFlowController>.value(
              value: h.controller,
            ),
          ],
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen at 200% text scale: no overflow while listening', (
    tester,
  ) async {
    final h = FlowHarness();
    await tester.pumpWidget(
      _scaled(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
            ChangeNotifierProvider<ApplicationFlowController>.value(
              value: h.controller,
            ),
          ],
          child: const HomeScreen(),
        ),
      ),
    );
    await h.fsm.transition(const TriggerPressed());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The button is still findable and at least its 72dp minimum — grown,
    // never clipped, if the label needed to wrap.
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, greaterThanOrEqualTo(72));
  });

  testWidgets('home screen at 200% text scale: no overflow with a long field label', (
    tester,
  ) async {
    final h = FlowHarness();
    await tester.pumpWidget(
      _scaled(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
            ChangeNotifierProvider<ApplicationFlowController>.value(
              value: h.controller,
            ),
          ],
          child: const HomeScreen(),
        ),
      ),
    );
    await h.fsm.transition(const TriggerPressed());
    await h.fsm.transition(
      const VoiceCommandRecognized('apply to this job'),
    );
    await h.fsm.transition(const IntentParsed());
    await h.fsm.transition(const TargetLoaded());
    await h.fsm.transition(const ContentRead());
    await h.fsm.transition(
      const ListingConfirmed([
        'n-email',
      ], fieldTypes: {'n-email': 'email'}),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings screen at 200% text scale: no overflow', (tester) async {
    final h = FlowHarness();
    await tester.pumpWidget(
      _scaled(
        MultiProvider(
          providers: [
            Provider<PreferencesService>.value(value: StubPrefs()),
            Provider<ApplicantProfileService>.value(value: MemoryProfileService()),
            Provider<FilePickerService>.value(value: StubFilePicker()),
            ChangeNotifierProvider<ApplicationFlowFsm>.value(value: h.fsm),
            ChangeNotifierProvider<ApplicationFlowController>.value(
              value: h.controller,
            ),
          ],
          child: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
