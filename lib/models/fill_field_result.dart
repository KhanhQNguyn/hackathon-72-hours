/// Result of `WebViewControllerService.fillField()` — whether the value
/// actually stuck after verification, not just whether the JS call
/// returned without error (spec.md §5 "Verify-after-action",
/// milestone16).
class FillFieldResult {
  final bool success;

  /// `'node_stale'` | `'value_did_not_stick'` | null (when `success` is
  /// true).
  final String? failureReason;

  const FillFieldResult({required this.success, this.failureReason});
}
