/// Result of `WebViewControllerService.detectCaptcha()` — Checkpoint 3
/// (`01-intent.md` §4, milestone13).
class CaptchaCheckResult {
  final bool detected;

  /// `'recaptcha'` | `'hcaptcha'` | `'unknown'` | null (when not
  /// detected).
  final String? provider;

  const CaptchaCheckResult({required this.detected, this.provider});
}
