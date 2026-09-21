import '../core/language.dart';
import '../core/narration_lookup.dart';
import '../services/tts_service.dart';
import '../services/webview_controller_service.dart';
import 'application_flow_fsm.dart';

/// Checkpoint 3 coordinator (`01-intent.md` §4, milestone13/14): checks
/// the currently-loaded page for a CAPTCHA, tries its accessible
/// audio-challenge option first, and only pauses the FSM for a user
/// hand-off if no audio option is found.
///
/// Deliberately a separate class rather than logic inside
/// `WebViewControllerService` or `ApplicationFlowFsm` — the former must
/// stay a thin JS-calling wrapper and the latter must stay pure Dart with
/// no platform/TTS calls of its own (`02-spec.md` §5 layering). This
/// class is the glue that depends on all three.
class CaptchaCheckpointHandler {
  final WebViewControllerService _webViewControllerService;
  final TtsService _ttsService;
  final Future<String> Function()? _getLanguage;

  /// [getLanguage] returns `'en'`/`'vi'`; without it the hand-off is
  /// spoken in Vietnamese, the language of the verbatim string.
  CaptchaCheckpointHandler(
    this._webViewControllerService,
    this._ttsService, {
    Future<String> Function()? getLanguage,
  }) : _getLanguage = getLanguage;

  Future<FlowNarration> _narration() async =>
      FlowNarration(await _getLanguage?.call() ?? AppLanguage.vi);

  /// The hand-off line in the active language (also mirrored on screen).
  Future<String> handOffText() async => (await _narration()).captchaHandOff;

  /// Exact narration string, quoted verbatim from `01-intent.md` §4 — do
  /// not rephrase.
  static const String handOffNarration = captchaHandOffVi;

  /// What was last spoken by [checkAndHandle], so the caller can mirror it
  /// on screen.
  String? lastSpoken;

  /// Checks for a CAPTCHA and hands it to the user if present. Returns true
  /// if a CAPTCHA was found, false if none was detected.
  ///
  /// Either way a CAPTCHA is found the FSM pauses (`CaptchaPendingState`)
  /// until the caller sees "continue". Pressing the audio-challenge button
  /// only *opens* the accessible challenge — somebody still has to listen
  /// and type the code — so it is not treated as solved (audit 1.5).
  Future<bool> checkAndHandle(ApplicationFlowFsm fsm) async {
    final check = await _webViewControllerService.detectCaptcha();
    if (!check.detected) return false;

    final openedAudio =
        await _webViewControllerService.tryResolveCaptchaViaAudio();
    final n = await _narration();
    lastSpoken = openedAudio ? n.captchaAudioOpened : n.captchaHandOff;

    await fsm.transition(const CaptchaEncountered());
    await _ttsService.speak(lastSpoken!);
    return true;
  }
}
