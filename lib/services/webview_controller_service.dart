import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/dom_snapshot.dart';

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
/// **Security note (milestone12 -> milestone17):** the `WebMessageListener`
/// below is registered with `allowedOriginRules: {"*"}` for now, so the
/// perceive-act-wait-perceive round trip (this milestone's own Definition
/// of Done) can be verified end-to-end. Restricting it to the loaded
/// page's exact origin is milestone17's job — do not treat the current
/// wildcard as final; it's a known, temporary gap, not an oversight.
class WebViewControllerService {
  InAppWebViewController? _controller;
  final StreamController<void> _domChangedController =
      StreamController<void>.broadcast();

  /// Fires whenever the currently-loaded page's DOM changes in place
  /// (via the injected `MutationObserver`) or the page finishes a full
  /// navigation (`onLoadStop`) — the perceive-act-wait-perceive trigger
  /// (spec.md §5, milestone12). Callers subscribe; they never poll.
  Stream<void> get domChangedEvents => _domChangedController.stream;

  /// `UserScript`s to pass to the `InAppWebView` widget's
  /// `initialUserScripts` (milestone12) so `dom_reader.js` is injected at
  /// `AT_DOCUMENT_START`, before the page's own scripts run.
  Future<List<UserScript>> loadInitialUserScripts() async {
    final domReaderSource = await rootBundle.loadString('assets/js/dom_reader.js');
    return [
      UserScript(
        source: domReaderSource,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      ),
    ];
  }

  /// `WebMessageListener`s to pass to the `InAppWebView` widget's
  /// `webMessageListeners` (milestone12) — receives `dom_changed`
  /// messages posted by `dom_reader.js`'s `MutationObserver` callback.
  List<WebMessageListener> get webMessageListeners => [
        WebMessageListener(
          jsObjectName: _bridgeJsObjectName,
          allowedOriginRules: {'*'}, // milestone17 tightens this
          onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
            _domChangedController.add(null);
          },
        ),
      ];

  /// Must be called from the hosting widget's `onLoadStop` callback
  /// (milestone12's "page-load listener" trigger).
  void notifyLoadStop() {
    _domChangedController.add(null);
  }

  /// Called from the widget hosting the `InAppWebView` once its
  /// controller is available (`onWebViewCreated`). Must be called before
  /// `loadTarget`/`readDom`/`fillField`. Registers `webMessageListeners`
  /// on the controller — `flutter_inappwebview` exposes this as a
  /// controller method (`addWebMessageListener`), not an `InAppWebView`
  /// widget constructor parameter (milestone12).
  Future<void> attachController(InAppWebViewController controller) async {
    _controller = controller;
    for (final listener in webMessageListeners) {
      await controller.addWebMessageListener(listener);
    }
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

  /// Hosts the target page in the embedded WebView (plan.md Workstream
  /// A1, the core spike target).
  Future<void> loadTarget(String url) {
    return _requireController.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
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
    );
  }

  // TODO: fillField(String fieldId, String value) -> bool, via
  // form_filler.js, with a re-read-to-verify step after filling
  // (spec.md §5, §6 "Form-Fill Orchestrator")
  Future<bool> fillField(String fieldId, String value) {
    throw UnimplementedError('form-filling — plan.md Workstream A3');
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
