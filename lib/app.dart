import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/theme.dart';
import 'mocks/fake_pdf_reader_service.dart';
import 'mocks/fake_webview_controller_service.dart';
import 'orchestration/application_flow_controller.dart';
import 'orchestration/application_flow_fsm.dart';
import 'orchestration/captcha_checkpoint_handler.dart';
import 'services/applicant_profile_service.dart';
import 'services/file_picker_service.dart';
import 'services/pdf_reader_service.dart';
import 'services/preferences_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';
import 'services/webview_controller_service.dart';
import 'ui/screens/home_screen.dart';
import 'utils/logger.dart';

/// MaterialApp root widget. See spec.md §5 (UI layer is MVVM, with the
/// FSM as the "ViewModel", exposed here via `provider`).
///
/// This is the single place service instances are constructed. With
/// [useMockServices] (the default until milestone 44) the WebView and PDF
/// layers are the fakes from `lib/mocks/`; everything else — STT, TTS, FSM,
/// storage, UI — is real. Providers are lazy, so nothing touches a
/// platform plugin until a screen reads it.
class App extends StatelessWidget {
  const App({super.key, this.useMockServices = AppConfig.useMockServices});

  final bool useMockServices;

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
        Provider<WebViewControllerService>(
          create: (_) => useMockServices
              ? FakeWebViewControllerService()
              : WebViewControllerService(),
        ),
        Provider<PdfReaderService>(
          create: (_) =>
              useMockServices ? FakePdfReaderService() : PdfReaderService(),
        ),
        ChangeNotifierProvider<ApplicationFlowFsm>(
          create: (_) => ApplicationFlowFsm(
            performRealSubmit: useMockServices
                ? () async => Logger.log('flow: mock submit (nothing sent)')
                : () async => throw UnimplementedError(
                    'real submit click — milestone 44',
                  ),
          ),
        ),
        Provider<CaptchaCheckpointHandler>(
          create: (ctx) => CaptchaCheckpointHandler(
            ctx.read<WebViewControllerService>(),
            ctx.read<TtsService>(),
          ),
        ),
        ChangeNotifierProvider<ApplicationFlowController>(
          create: (ctx) => ApplicationFlowController(
            fsm: ctx.read<ApplicationFlowFsm>(),
            speech: ctx.read<SpeechService>(),
            tts: ctx.read<TtsService>(),
            preferences: ctx.read<PreferencesService>(),
            webView: ctx.read<WebViewControllerService>(),
            pdfReader: ctx.read<PdfReaderService>(),
            profileService: ctx.read<ApplicantProfileService>(),
            filePicker: ctx.read<FilePickerService>(),
            captchaHandler: ctx.read<CaptchaCheckpointHandler>(),
          ),
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
