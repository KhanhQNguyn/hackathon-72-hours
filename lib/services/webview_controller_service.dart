import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/captcha_check_result.dart';
import '../models/dom_snapshot.dart';
import '../models/fill_field_result.dart';
import '../utils/logger.dart';
import 'page_load_exception.dart';

/// JS object name the `WebMessageListener` is registered under — must
/// match `dom_reader.js`'s `window.jobAccessAssistBridge.postMessage(...)`
/// calls exactly (milestone12).
const String _bridgeJsObjectName = 'jobAccessAssistBridge';

/// Dart side of the WebView + JS-bridge, backed by `flutter_inappwebview`
/// (spec.md §5). Loads the target page, injects `assets/js/dom_reader.js`
/// and `assets/js/form_filler.js` as `UserScript`s (`AT_DOCUMENT_START`,
/// so a `MutationObserver` attaches before the page's own scripts run),
/// and exposes DOM read/fill results back to Dart via a
/// `WebMessageListener`.
///
/// **Security note (milestone17):** the `WebMessageListener` is
/// registered lazily, on the first `loadTarget()` call, with
/// `allowedOriginRules` restricted to that URL's exact origin (not a
/// wildcard). `InAppWebViewController` has no method to remove or update
/// an already-registered listener's `allowedOriginRules` (checked against
/// the plugin's public API — only `addWebMessageListener`/
/// `hasWebMessageListener` exist), so if a later `loadTarget()` call
/// targets a different origin, the bridge keeps accepting messages only
/// from the originally-registered origin; this is logged loudly via
/// [Logger] rather than silently ignored. This is a known, honestly-
/// documented plugin limitation, not an oversight — see milestone17.
class WebViewControllerService {
  InAppWebViewController? _controller;
  final StreamController<void> _domChangedController =
      StreamController<void>.broadcast();

  /// Set once, the first time a `WebMessageListener` is registered
  /// (milestone17). Null until the first `loadTarget()` call.
  String? _registeredOrigin;

  /// Completed by [notifyLoadStop] (success) or [notifyLoadError]/the
  /// 15s timeout (failure) inside the in-flight `loadTarget()` call
  /// (milestone22). Null when no load is in flight.
  Completer<void>? _pendingLoadCompleter;

  /// Fires whenever the currently-loaded page's DOM changes in place
  /// (via the injected `MutationObserver`) or the page finishes a full
  /// navigation (`onLoadStop`) — the perceive-act-wait-perceive trigger
  /// (spec.md §5, milestone12). Callers subscribe; they never poll.
  Stream<void> get domChangedEvents => _domChangedController.stream;

  /// `UserScript`s to pass to the `InAppWebView` widget's
  /// `initialUserScripts` (milestone12): `dom_reader.js` and
  /// `form_filler.js`, both at `AT_DOCUMENT_START`, so the
  /// `MutationObserver` attaches before the page's own scripts run and
  /// the `window.__formFiller_*` functions exist by the time
  /// `fillField`/`triggerFileChooser` call them. (`form_filler.js` was
  /// missing here until the milestone44 integration pass — every real
  /// `fillField` would have failed with "is not a function".)
  Future<List<UserScript>> loadInitialUserScripts() async {
    final domReaderSource = await rootBundle.loadString('assets/js/dom_reader.js');
    final formFillerSource = await rootBundle.loadString('assets/js/form_filler.js');
    return [
      UserScript(
        source: domReaderSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
      UserScript(
        source: formFillerSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ];
  }

  /// Builds a `WebMessageListener` restricted to [origin] (milestone17) —
  /// receives `dom_changed` messages posted by `dom_reader.js`'s
  /// `MutationObserver` callback.
  WebMessageListener _buildWebMessageListener(String origin) {
    return WebMessageListener(
      jsObjectName: _bridgeJsObjectName,
      allowedOriginRules: {origin},
      onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
        _domChangedController.add(null);
      },
    );
  }

  /// Registers the origin-restricted `WebMessageListener` the first time
  /// it's needed (from the first `loadTarget()` call). On any later call
  /// with a different origin, the listener can't be re-registered (no
  /// remove/update API — see class doc), so this only logs the drift
  /// instead of silently pretending the bridge follows navigation
  /// (milestone17).
  Future<void> _ensureOriginRegistered(String origin) async {
    if (_registeredOrigin == null) {
      await _requireController.addWebMessageListener(
        _buildWebMessageListener(origin),
      );
      _registeredOrigin = origin;
    } else if (_registeredOrigin != origin) {
      Logger.log(
        'WebViewControllerService: page navigated from '
        '$_registeredOrigin to $origin, but the JS bridge listener '
        'cannot be re-registered (flutter_inappwebview has no '
        'remove/update API for WebMessageListener) — messages from '
        '$origin will NOT reach $_bridgeJsObjectName.',
      );
    }
  }

  /// Must be called from the hosting widget's `onLoadStop` callback
  /// (milestone12's "page-load listener" trigger; also milestone22's
  /// load-succeeded signal for the in-flight `loadTarget()` timeout).
  void notifyLoadStop() {
    _domChangedController.add(null);
    final completer = _pendingLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Must be called from the hosting widget's `onReceivedError` callback,
  /// for main-frame errors only — sub-resource failures (blocked ad/
  /// tracker scripts, a broken image, etc.) are not page-load failures
  /// and must not abort the in-flight `loadTarget()` (milestone22).
  void notifyLoadError(String description) {
    final completer = _pendingLoadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(PageLoadException(description));
    }
  }

  /// Called from the widget hosting the `InAppWebView` once its
  /// controller is available (`onWebViewCreated`). Must be called before
  /// `loadTarget`/`readDom`/`fillField`. The `WebMessageListener` itself
  /// is registered lazily by `loadTarget()` (milestone17), once the
  /// target origin is known — not here.
  Future<void> attachController(InAppWebViewController controller) async {
    _controller = controller;
  }

  InAppWebViewController get _requireController {
    final controller = _controller;
    if (controller == null) {
      throw StateError(
        'WebViewControllerService: no WebView attached yet — call '
        'attachController() from onWebViewCreated first (plan.md A1).',
      );
    }
    return controller;
  }

  /// 15s, generous for a mobile network but still bounded (milestone22,
  /// `02-spec.md` §3).
  static const Duration _loadTimeout = Duration(seconds: 15);

  /// Hosts the target page in the embedded WebView (plan.md Workstream
  /// A1, the core spike target). Registers the origin-restricted JS
  /// bridge listener on first use (milestone17), then waits for either
  /// the hosting widget's `onLoadStop` (success, via [notifyLoadStop]) or
  /// `onReceivedError`/a 15s timeout (failure), throwing
  /// [PageLoadException] in the latter case (milestone22).
  Future<void> loadTarget(String url) async {
    final origin = Uri.parse(url).origin;
    await _ensureOriginRegistered(origin);

    final completer = Completer<void>();
    _pendingLoadCompleter = completer;
    Timer? timer;

    try {
      await _requireController.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      timer = Timer(_loadTimeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            const PageLoadException("that didn't load as expected, retrying..."),
          );
        }
      });
      await completer.future;
    } finally {
      // Covers loadUrl() itself throwing, not just the timeout/onLoadStop
      // race — otherwise a synchronous loadUrl() failure would leave
      // _pendingLoadCompleter pointing at a completer nothing will ever
      // complete.
      timer?.cancel();
      if (identical(_pendingLoadCompleter, completer)) {
        _pendingLoadCompleter = null;
      }
    }
  }

  Future<dynamic> _evalJson(String expression) async {
    final result = await _requireController.evaluateJavascript(source: expression);
    if (result == null) return null;
    return jsonDecode(result as String);
  }

  /// Reads the currently-loaded page's DOM via `dom_reader.js`: images,
  /// heuristically-narrowed search/submit candidates, every labeled
  /// field, and visible text (spec.md §5-§6, milestones 09-12).
  Future<DomSnapshot> readDom() async {
    final imagesJson = await _evalJson('window.__domReader_getImages()') as List<dynamic>;
    final searchJson =
        await _evalJson('window.__domReader_getSearchCandidates()') as List<dynamic>;
    final submitJson =
        await _evalJson('window.__domReader_getSubmitCandidates()') as List<dynamic>;
    final labeledJson =
        await _evalJson('window.__domReader_getLabeledFields()') as List<dynamic>;
    final textJson =
        await _evalJson('window.__domReader_getVisibleText()') as Map<String, dynamic>;
    final captchaJson =
        await _evalJson('window.__domReader_detectCaptcha()') as Map<String, dynamic>;

    return DomSnapshot(
      images: imagesJson
          .cast<Map<String, dynamic>>()
          .map(
            (j) => DomImage(
              src: j['src'] as String,
              altText: j['alt'] as String?,
              hasAlt: j['hasAlt'] as bool,
            ),
          )
          .toList(),
      searchCandidates: searchJson
          .cast<Map<String, dynamic>>()
          .map(DomFormField.fromJson)
          .toList(),
      submitCandidates: submitJson
          .cast<Map<String, dynamic>>()
          .map(DomFormField.fromJson)
          .toList(),
      labeledFields: labeledJson
          .cast<Map<String, dynamic>>()
          .map(DomFormField.fromJson)
          .toList(),
      visibleText: textJson['text'] as String,
      truncated: textJson['truncated'] as bool,
      captchaDetected: captchaJson['detected'] as bool,
      captchaProvider: captchaJson['provider'] as String?,
    );
  }

  /// Checkpoint 3 — standalone CAPTCHA check (milestone13), for callers
  /// (e.g. a CAPTCHA-checkpoint coordinator) that don't need a full
  /// `readDom()` pass just to ask "is there a CAPTCHA right now?".
  Future<CaptchaCheckResult> detectCaptcha() async {
    final json = await _evalJson('window.__domReader_detectCaptcha()')
        as Map<String, dynamic>;
    return CaptchaCheckResult(
      detected: json['detected'] as bool,
      provider: json['provider'] as String?,
    );
  }

  /// Tries the CAPTCHA's own accessible audio-challenge option before
  /// giving up to a user hand-off (milestone14, `01-intent.md` §4). Polls
  /// 5 attempts x 400ms — the widget may still be rendering when the
  /// CAPTCHA is first detected. Returns true iff the audio button was
  /// found and clicked.
  Future<bool> tryResolveCaptchaViaAudio() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final json = await _evalJson(
        'window.__domReader_findAndClickAudioChallengeButton()',
      ) as Map<String, dynamic>;
      if (json['clicked'] == true) return true;
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return false;
  }

  /// Sets [nodeId]'s value and verifies it actually stuck (milestone16,
  /// `02-spec.md` §5 "Verify-after-action"). On `node_stale` — the node
  /// was removed/re-rendered since the last `readDom()` tagged it — does
  /// exactly one internal `readDom()` (re-tagging elements with fresh
  /// `data-app-node-id`s) and retries the fill exactly once before giving
  /// up (`02-spec.md` §3 "retry once or twice").
  ///
  /// **Known limitation:** the retry reuses the same [nodeId]. That only
  /// helps if the element merely lost its tag transiently (e.g. a
  /// framework re-render stripped the attribute but the same node is
  /// still there); if the node was genuinely replaced, `readDom()` tags
  /// the replacement with a brand-new id and this retry can't recover it
  /// — the caller would need to re-resolve which field to fill from a
  /// fresh `DomSnapshot`, which is outside this method's scope (it only
  /// knows a nodeId + value, not field semantics).
  Future<FillFieldResult> fillField(String nodeId, String value) async {
    final result = await _fillFieldOnce(nodeId, value);
    if (result.success || result.failureReason != 'node_stale') {
      return result;
    }
    await readDom();
    return _fillFieldOnce(nodeId, value);
  }

  Future<FillFieldResult> _fillFieldOnce(String nodeId, String value) async {
    final setJson = await _evalJson(
      'window.__formFiller_setValue(${jsonEncode(nodeId)}, ${jsonEncode(value)})',
    ) as Map<String, dynamic>;
    if (setJson['success'] != true) {
      return FillFieldResult(
        success: false,
        failureReason: setJson['reason'] as String?,
      );
    }

    // Give the host page's own reactive framework a chance to re-render
    // before verifying — a short Dart-side delay in place of relying on
    // `evaluateJavascript` auto-awaiting a JS Promise, which it does not
    // do in the default content world (see form_filler.js's top comment).
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final verifyJson = await _evalJson(
      'window.__formFiller_verifyValue(${jsonEncode(nodeId)}, ${jsonEncode(value)})',
    ) as Map<String, dynamic>;
    return FillFieldResult(
      success: verifyJson['success'] == true,
      failureReason: verifyJson['reason'] as String?,
    );
  }

  /// Summons the native file chooser for a `<input type="file">` field
  /// (milestone21). JS can't set a file input's value directly (browser
  /// security), but can call `.click()` on it, which
  /// `flutter_inappwebview`'s Android side already handles internally
  /// (its `WebChromeClient.onShowFileChooser` launches its own native
  /// picker intent) — there is no Dart-level `onShowFileChooser` hook to
  /// wire in this plugin version (checked against the plugin's Dart and
  /// native Android source; that part of the milestone's stated
  /// mechanism doesn't exist here). Returns `false` if [nodeId] wasn't
  /// found or isn't a file input.
  Future<bool> triggerFileChooser(String nodeId) async {
    final json = await _evalJson(
      'window.__formFiller_clickFileInput(${jsonEncode(nodeId)})',
    ) as Map<String, dynamic>;
    return json['success'] == true;
  }

  /// The name of the file currently held by the `<input type="file">`
  /// [nodeId], or `null` if none / the node is gone (audit 1.4b). Used to
  /// confirm the user really attached something in the system chooser.
  Future<String?> getFileInputName(String nodeId) async {
    final json = await _evalJson(
      'window.__formFiller_getFileName(${jsonEncode(nodeId)})',
    ) as Map<String, dynamic>;
    final name = json['name'];
    return json['success'] == true && name is String && name.isNotEmpty
        ? name
        : null;
  }

  /// Clicks [nodeId] (milestone44) — used only for the final submit
  /// button, from the FSM's gated submit action. Returns `false` if the
  /// node is gone.
  Future<bool> clickElement(String nodeId) async {
    final json = await _evalJson(
      'window.__formFiller_clickElement(${jsonEncode(nodeId)})',
    ) as Map<String, dynamic>;
    return json['success'] == true;
  }

  // TODO: focusElement(String nodeRef) — Feature 2 "Guided TalkBack
  // Assist" (intent.md §4). Relies entirely on the WebView's own
  // accessibility bridge to Android's TalkBack for the resulting
  // announcement — no separate accessibility mechanism of this
  // project's own. UNCONFIRMED on a real device pending spike A1b
  // (plan.md) — do not assume this works, and do not wire it into the
  // FSM as if it were load-bearing for Feature 1.
  Future<void> focusElement(String nodeRef) {
    throw UnimplementedError(
      'focusElement (.focus() via JS bridge) — Feature 2, pending spike A1b',
    );
  }
}
