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

  CaptchaCheckpointHandler(this._webViewControllerService, this._ttsService);

  /// Exact narration string, quoted verbatim from `01-intent.md` §4 — do
  /// not rephrase.
  static const String handOffNarration =
      "Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé";

  static const String audioResolvedNarration =
      'Đã dùng tùy chọn âm thanh cho CAPTCHA';

  /// Checks for a CAPTCHA and handles it if present. Returns true if a
  /// CAPTCHA was found (whether auto-resolved via audio or handed off to
  /// the user), false if none was detected — callers use this to decide
  /// whether to proceed with the perception pass that triggered the
  /// check.
  Future<bool> checkAndHandle(ApplicationFlowFsm fsm) async {
    final check = await _webViewControllerService.detectCaptcha();
    if (!check.detected) return false;

    final resolvedViaAudio =
        await _webViewControllerService.tryResolveCaptchaViaAudio();
    if (resolvedViaAudio) {
      await _ttsService.speak(audioResolvedNarration);
      return true;
    }

    await fsm.transition(const CaptchaEncountered());
    await _ttsService.speak(handOffNarration);
    return true;
  }
}
