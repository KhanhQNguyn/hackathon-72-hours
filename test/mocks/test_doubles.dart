import 'dart:typed_data';

import 'package:job_access_assist/mocks/fake_pdf_reader_service.dart';
import 'package:job_access_assist/mocks/fake_webview_controller_service.dart';
import 'package:job_access_assist/models/captcha_check_result.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/models/element_match_result.dart';
import 'package:job_access_assist/models/fill_field_result.dart';
import 'package:job_access_assist/models/job_listing.dart';
import 'package:job_access_assist/models/openai_results.dart';
import 'package:job_access_assist/models/pdf_form_field.dart';
import 'package:job_access_assist/models/voice_command_result.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/orchestration/captcha_checkpoint_handler.dart';
import 'package:job_access_assist/orchestration/submit_hook.dart';
import 'package:job_access_assist/services/applicant_profile_service.dart';
import 'package:job_access_assist/services/file_picker_service.dart';
import 'package:job_access_assist/services/openai_service.dart';
import 'package:job_access_assist/services/preferences_service.dart';
import 'package:job_access_assist/services/speech_service.dart';
import 'package:job_access_assist/services/tts_service.dart';

/// Plays back a fixed list of utterances (confidence 0.9). Once the script
/// runs out it returns silence, which the confidence gate rejects.
class ScriptedSpeech implements SpeechService {
  ScriptedSpeech(List<String> script) : _script = List.of(script);
  final List<String> _script;

  @override
  Future<VoiceCommandResult> listen() async {
    if (_script.isEmpty) {
      return const VoiceCommandResult(
        transcript: '',
        confidence: 0.0,
        alternatives: [],
      );
    }
    final text = _script.removeAt(0);
    return VoiceCommandResult(
      transcript: text,
      confidence: 0.9,
      alternatives: [text, '$text alt'],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingTts implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubPrefs implements PreferencesService {
  StubPrefs([this.language = 'en']);
  String language;

  @override
  Future<String> getLanguagePref() async => language;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryProfileService implements ApplicantProfileService {
  MemoryProfileService([this.profile]);
  Map<String, String>? profile;

  @override
  Future<Map<String, String>?> getProfile() async => profile;

  @override
  Future<void> saveProfile(Map<String, String> p) async => profile = p;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubFilePicker implements FilePickerService {
  StubFilePicker([this.path]);
  String? path;
  int calls = 0;

  @override
  Future<String?> pickCvFile() async {
    calls++;
    return path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The canned WebView fake that also records what was filled and clicked.
class SpyWebView extends FakeWebViewControllerService {
  final Map<String, String> filled = {};
  final List<String> fileChooserNodes = [];
  final List<String> clicked = [];
  bool failFills = false;
  bool clickSucceeds = true;

  /// What the page reports as attached after the file chooser closes;
  /// `null` = the user cancelled / nothing attached.
  String? attachedFileName = 'cv.pdf';
  bool chooserOpens = true;

  /// Fails the next N `clickElement` calls, then succeeds.
  int failClicks = 0;

  /// Fails the next N `fillField` calls, then succeeds.
  int failFillTimes = 0;

  /// Called when the page's file chooser is triggered.
  void Function()? onTriggerFileChooser;
  DomSnapshot? snapshotOverride;

  bool captchaPresent = false;
  bool audioButtonFound = false;
  int captchaChecks = 0;

  @override
  Future<CaptchaCheckResult> detectCaptcha() async {
    captchaChecks++;
    return CaptchaCheckResult(detected: captchaPresent);
  }

  @override
  Future<bool> tryResolveCaptchaViaAudio() async => audioButtonFound;

  @override
  Future<DomSnapshot> readDom() async =>
      snapshotOverride ?? await super.readDom();

  @override
  Future<FillFieldResult> fillField(String nodeId, String value) async {
    if (failFillTimes > 0) {
      failFillTimes--;
      return const FillFieldResult(
        success: false,
        failureReason: 'value_did_not_stick',
      );
    }
    if (failFills) {
      return const FillFieldResult(
        success: false,
        failureReason: 'value_did_not_stick',
      );
    }
    filled[nodeId] = value;
    return const FillFieldResult(success: true);
  }

  @override
  Future<bool> triggerFileChooser(String nodeId) async {
    onTriggerFileChooser?.call();
    fileChooserNodes.add(nodeId);
    return chooserOpens;
  }

  @override
  Future<String?> getFileInputName(String nodeId) async => attachedFileName;

  @override
  Future<bool> clickElement(String nodeId) async {
    clicked.add(nodeId);
    if (failClicks > 0) {
      failClicks--;
      return false;
    }
    return clickSucceeds;
  }

  /// Overrides the fake base class's default `true` for the real-target
  /// demo flow's success-detection tests (item F).
  bool? detectApplySuccessOverride;

  @override
  Future<bool> detectApplySuccess() async =>
      detectApplySuccessOverride ?? await super.detectApplySuccess();
}

/// A scripted stand-in for the OpenAI layer.
class FakeOpenAi implements OpenAiService {
  /// Intent results returned in order (the last one repeats).
  List<IntentResult> intents = [
    const IntentResult(intentType: IntentType.fillAndSubmit, confidence: 0.95),
  ];
  int intentCalls = 0;
  int failIntentTimes = 0;
  String? lastTranscript;
  List<String>? lastAlternatives;

  ListingSummary? summary;
  ImageTranscription? image = const ImageTranscription(
    text: 'Job posting text from the picture',
    confidence: 0.9,
  );
  final List<String> imageBase64Calls = [];
  PdfStructure? pdf;
  ElementMatchResult? match;
  final List<String> matchTargets = [];

  @override
  bool get isConfigured => true;

  @override
  Future<IntentResult> parseIntent({
    required String transcript,
    List<String> alternatives = const [],
    required String languagePref,
  }) async {
    intentCalls++;
    if (failIntentTimes > 0) {
      failIntentTimes--;
      throw const OpenAiException('offline');
    }
    lastTranscript = transcript;
    lastAlternatives = alternatives;
    return intents[(intentCalls - 1).clamp(0, intents.length - 1)];
  }

  @override
  Future<ImageTranscription> imageToText({
    required String imageBase64,
    String mimeType = 'image/png',
  }) async {
    imageBase64Calls.add(imageBase64);
    return image!;
  }

  @override
  Future<ListingSummary> summarizeListing({
    required String pageText,
    required String url,
  }) async {
    final s = summary;
    if (s == null) throw const OpenAiException('no summary scripted');
    return s;
  }

  @override
  Future<PdfStructure> structurePdf({
    required String rawPdfText,
    List<PdfFormField> detectedFormFields = const [],
  }) async {
    final p = pdf;
    if (p == null) throw const OpenAiException('no structure scripted');
    return p;
  }

  @override
  Future<ElementMatchResult> matchElement({
    required String targetDescription,
    required List<DomFormField> candidates,
  }) async {
    matchTargets.add(targetDescription);
    final m = match;
    if (m == null) throw const OpenAiException('no match scripted');
    return m;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _tinyImage = [1, 2, 3];

class FlowHarness {
  FlowHarness({
    List<String> script = const [],
    Map<String, String>? profile = const {
      'name': 'Alex Nguyen',
      'phone': '0900000000',
      'email': 'alex@example.com',
      'cvFilePath': '/storage/cv.pdf',
    },
    String language = 'en',
    this.ai,
    bool wireSubmitHook = false,
    Duration settleDelay = Duration.zero,
    Duration settleMaxWait = const Duration(seconds: 8),
    int maxVoiceRetries = 2,
    SpeechService? speech,
  }) : tts = RecordingTts(),
       web = SpyWebView() {
    final hook = wireSubmitHook ? SubmitHook() : null;
    fsm = ApplicationFlowFsm(
      performRealSubmit: hook != null ? hook.run : () async => submitCalls++,
    );
    controller = ApplicationFlowController(
      fsm: fsm,
      speech: speech ?? ScriptedSpeech(script),
      tts: tts,
      preferences: StubPrefs(language),
      webView: web,
      pdfReader: FakePdfReaderService(),
      profileService: MemoryProfileService(profile),
      captchaHandler: CaptchaCheckpointHandler(
        web,
        tts,
        getLanguage: StubPrefs(language).getLanguagePref,
      ),
      openAi: ai,
      imageFetcher: (url) async => FetchedImage(Uint8List.fromList(_tinyImage), 'image/png'),
      submitHook: hook,
      settleDelay: settleDelay,
      settleMaxWait: settleMaxWait,
      maxVoiceRetries: maxVoiceRetries,
      awaitFileChooser: () async {
        chooserWaits++;
      },
    );
  }

  final RecordingTts tts;
  final SpyWebView web;
  final FakeOpenAi? ai;
  late final ApplicationFlowFsm fsm;
  late final ApplicationFlowController controller;
  int submitCalls = 0;
  int chooserWaits = 0;
}

/// A job listing with the given submit candidates, for submit-choice tests.
DomSnapshot snapshotWithSubmit(List<DomFormField> submit) => DomSnapshot(
  images: const [],
  searchCandidates: const [],
  submitCandidates: submit,
  labeledFields: const [],
  visibleText: 'text',
  truncated: false,
);

/// A sample job listing for scripted summaries.
const sampleListing = JobListing(
  title: 'Flutter Developer',
  company: 'Example Co',
  requirements: '3 years Flutter',
  howToApply: 'Fill in the form',
);
