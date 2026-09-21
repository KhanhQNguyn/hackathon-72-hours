/// Thrown by `WebViewControllerService.loadTarget()` when the page
/// doesn't finish loading within the bounded timeout, or the WebView
/// reports a main-frame load error (`02-spec.md` §3, milestone22).
class PageLoadException implements Exception {
  final String message;

  const PageLoadException(this.message);

  @override
  String toString() => 'PageLoadException: $message';
}
