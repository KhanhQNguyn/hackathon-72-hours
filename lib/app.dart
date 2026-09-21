import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/theme.dart';
import 'mocks/fake_pdf_reader_service.dart';
import 'mocks/fake_webview_controller_service.dart';
import 'orchestration/application_flow_controller.dart';
import 'orchestration/application_flow_fsm.dart';
import 'orchestration/captcha_checkpoint_handler.dart';
import 'orchestration/submit_hook.dart';
import 'services/applicant_profile_service.dart';
import 'services/file_picker_service.dart';
import 'services/fuzzy_match_service.dart';
import 'services/openai_service.dart';
import 'services/pdf_reader_service.dart';
import 'services/preferences_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';
import 'services/webview_controller_service.dart';
import 'ui/screens/home_screen.dart';

/// MaterialApp root widget. See spec.md §5 (UI layer is MVVM, with the
/// FSM as the "ViewModel", exposed here via `provider`).
///
/// This is the single place service instances are constructed. With
/// [useMockServices] the WebView and PDF layers are the fakes from
/// `lib/mocks/`; everything else — STT, TTS, OpenAI, FSM, storage, UI — is
/// real. With it off (milestone 44) the real WebView and PDF services are
/// used and the page is shown on the home screen. Providers are lazy, so
/// nothing touches a platform plugin until a screen reads it.
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
        Provider<OpenAiService>(create: (_) => OpenAiService()),
        Provider<FuzzyMatchService>(create: (_) => FuzzyMatchService()),
        Provider<SubmitHook>(create: (_) => SubmitHook()),
        // The FSM is the only caller of the real submit; the hook is
        // filled in by the flow controller, which needs the FSM first.
        ChangeNotifierProvider<ApplicationFlowFsm>(
          create: (ctx) => ApplicationFlowFsm(
            performRealSubmit: ctx.read<SubmitHook>().run,
          ),
        ),
        Provider<CaptchaCheckpointHandler>(
          create: (ctx) => CaptchaCheckpointHandler(
            ctx.read<WebViewControllerService>(),
            ctx.read<TtsService>(),
            getLanguage: ctx.read<PreferencesService>().getLanguagePref,
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
            openAi: ctx.read<OpenAiService>(),
            fuzzy: ctx.read<FuzzyMatchService>(),
            submitHook: ctx.read<SubmitHook>(),
            // A real run has no listing-to-PDF link to follow yet, so the
            // user picks the form; mocked runs use a canned one.
            formPdfPathProvider: useMockServices
                ? null
                : ctx.read<FilePickerService>().pickPdfFile,
            askUserToChooseFormPdf: !useMockServices,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Job Access Assist',
        theme: AppTheme.theme,
        home: HomeScreen(showWebView: !useMockServices),
      ),
    );
  }
}
