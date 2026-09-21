# Milestone 17 — `WebMessageListener` origin restriction

**One-line goal:** restrict which page origins can post messages back into the app's JS bridge, since the target is a real, uncontrolled third-party site that could embed untrusted ad/tracker scripts.

## Project context
`02-spec.md` §1: *"since the target content is a real, uncontrolled third-party site, `webview_flutter`'s `addJavaScriptChannel` cannot verify which script on the page triggered a message... `flutter_inappwebview`'s `WebMessageListener` can restrict which origins may send messages."* This is exactly why the project uses `flutter_inappwebview` instead of `webview_flutter` — this milestone is where that reasoning actually gets implemented, not just cited.

## Maps to plan.md task(s)
A3 (part 3 of 3)

## Preconditions
Milestone 15 (needs the message-posting mechanism to exist first)

## Files touched
- `lib/services/webview_controller_service.dart` — edit

## Implementation spec
- When registering the `WebMessageListener` (`flutter_inappwebview`'s `addWebMessageListener`), set `allowedOriginRules` to the **exact origin** of the currently-loaded target page (scheme + host + port), computed from the URL passed to `loadTarget()` — **not** a wildcard (`*`).
- Since the target page can navigate to other pages within the same portal, recompute and re-register (or update) the allowed-origin rule on every `onLoadStop`, not just once at app start.

## Definition of Done
- [ ] A local fixture page that itself embeds an `<iframe>` from a different fake origin, attempting to post a message into the app's channel → the message is rejected (the `WebViewControllerService` stream emits nothing for that attempt)
- [ ] A message from the actual top-level page's own injected script IS delivered, in the same test session

## Size
S
