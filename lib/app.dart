import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'orchestration/application_flow_fsm.dart';
import 'services/applicant_profile_service.dart';
import 'services/file_picker_service.dart';
import 'services/preferences_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';
import 'ui/screens/home_screen.dart';

/// MaterialApp root widget. See spec.md §5 (UI layer is MVVM, with the
/// FSM as the "ViewModel", exposed here via `provider`).
///
/// Services are provided lazily (Provider's default), so nothing touches
/// a platform plugin until a screen actually reads it. This is the single
/// place service instances are constructed — swap real for fake here.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PreferencesService>(create: (_) => PreferencesService()),
        Provider<TtsService>(
          create: (ctx) =>
              TtsService(preferences: ctx.read<PreferencesService>()),
        ),
        Provider<SpeechService>(
          create: (ctx) =>
              SpeechService(preferences: ctx.read<PreferencesService>()),
        ),
        Provider<ApplicantProfileService>(
          create: (_) => ApplicantProfileService(),
        ),
        Provider<FilePickerService>(create: (_) => FilePickerService()),
        ChangeNotifierProvider<ApplicationFlowFsm>(
          create: (_) => ApplicationFlowFsm(),
        ),
      ],
      child: MaterialApp(
        title: 'Job Access Assist',
        theme: AppTheme.theme,
        home: const HomeScreen(),
      ),
    );
  }
}
