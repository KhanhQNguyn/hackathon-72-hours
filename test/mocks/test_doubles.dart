import 'package:job_access_assist/mocks/fake_pdf_reader_service.dart';
import 'package:job_access_assist/mocks/fake_webview_controller_service.dart';
import 'package:job_access_assist/models/fill_field_result.dart';
import 'package:job_access_assist/models/voice_command_result.dart';
import 'package:job_access_assist/orchestration/application_flow_controller.dart';
import 'package:job_access_assist/orchestration/application_flow_fsm.dart';
import 'package:job_access_assist/orchestration/captcha_checkpoint_handler.dart';
import 'package:job_access_assist/services/applicant_profile_service.dart';
import 'package:job_access_assist/services/file_picker_service.dart';
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
      alternatives: [text],
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

/// The canned WebView fake that also records what was filled.
class SpyWebView extends FakeWebViewControllerService {
  final Map<String, String> filled = {};
  final List<String> fileChooserNodes = [];
  bool failFills = false;

  @override
  Future<FillFieldResult> fillField(String nodeId, String value) async {
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
    fileChooserNodes.add(nodeId);
    return true;
  }
}

class FlowHarness {
  FlowHarness({
    List<String> script = const [],
    Map<String, String>? profile = const {
      'name': 'Alex Nguyen',
      'phone': '0900000000',
      'email': 'alex@example.com',
      'cvFilePath': '/storage/cv.pdf',
    },
    String? pickerPath,
    String language = 'en',
  }) : tts = RecordingTts(),
       web = SpyWebView(),
       picker = StubFilePicker(pickerPath) {
    fsm = ApplicationFlowFsm(performRealSubmit: () async => submitCalls++);
    controller = ApplicationFlowController(
      fsm: fsm,
      speech: ScriptedSpeech(script),
      tts: tts,
      preferences: StubPrefs(language),
      webView: web,
      pdfReader: FakePdfReaderService(),
      profileService: MemoryProfileService(profile),
      filePicker: picker,
      captchaHandler: CaptchaCheckpointHandler(web, tts),
    );
  }

  final RecordingTts tts;
  final SpyWebView web;
  final StubFilePicker picker;
  late final ApplicationFlowFsm fsm;
  late final ApplicationFlowController controller;
  int submitCalls = 0;
}
