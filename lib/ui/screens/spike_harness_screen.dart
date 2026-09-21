import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../services/webview_controller_service.dart';
import '../../utils/logger.dart';

/// Throwaway debug screen for milestone 01 (DOM-reading spike) and
/// milestone 02 (`.focus()` -> TalkBack spike). Not part of
/// `05-scaffolder.md`'s tree — explicitly temporary. Delete this file, or
/// keep it reachable only via the debug-only entry point in
/// `home_screen.dart` (gated on `kDebugMode`), once both spikes have
/// produced a pass/fail result recorded back into `01-intent.md`/
/// `02-spec.md`.
///
/// The "Read DOM" button (milestone 01) and "Focus element" button
/// (milestone 02) deliberately run ad-hoc inline JavaScript via the raw
/// `InAppWebViewController`, NOT through `WebViewControllerService`'s
/// `readDom()`/`focusElement()` — those get their real, production
/// implementations in milestones 09-12 and beyond. This screen only
/// needs `WebViewControllerService.loadTarget()`, which is real,
/// permanent API surface reused later.
class SpikeHarnessScreen extends StatefulWidget {
  const SpikeHarnessScreen({super.key});

  @override
  State<SpikeHarnessScreen> createState() => _SpikeHarnessScreenState();
}

class _SpikeHarnessScreenState extends State<SpikeHarnessScreen> {
  final WebViewControllerService _webViewControllerService =
      WebViewControllerService();
  final TextEditingController _urlController = TextEditingController(
    // Placeholder only — VietnamWorks is the confirmed target platform
    // (01-intent.md §5), but the specific listing to spike against is
    // still an open item (01-intent.md §7). Replace with the team's
    // actual chosen listing URL before running the real spike.
    text: 'https://www.vietnamworks.com',
  );
  InAppWebViewController? _controller;
  String _lastResult = '(no result yet)';
  List<UserScript>? _initialUserScripts;
  StreamSubscription<void>? _domChangedSubscription;
  int _domChangedCount = 0;

  @override
  void initState() {
    super.initState();
    _webViewControllerService.loadInitialUserScripts().then((scripts) {
      if (!mounted) return;
      setState(() => _initialUserScripts = scripts);
    });
    _domChangedSubscription = _webViewControllerService.domChangedEvents.listen((_) {
      _domChangedCount++;
      Logger.log('spike_harness: domChangedEvents fired (count=$_domChangedCount)');
    });
  }

  static const String _readDomScript = '''
(function() {
  var images = Array.prototype.slice.call(document.querySelectorAll('img')).map(function(img) {
    return { src: img.src, alt: img.getAttribute('alt') };
  });
  var inputs = Array.prototype.slice.call(document.querySelectorAll('input')).map(function(input) {
    return {
      tag: input.tagName.toLowerCase(),
      type: input.getAttribute('type'),
      placeholder: input.getAttribute('placeholder')
    };
  });
  var textSample = (document.body && document.body.innerText || '').substring(0, 500);
  return JSON.stringify({ images: images, inputs: inputs, textSample: textSample });
})();
''';

  static const String _focusFirstInputScript = '''
(function() {
  var el = document.querySelector('input');
  if (!el) { return JSON.stringify({ focused: false, reason: 'no_input_found' }); }
  el.focus();
  return JSON.stringify({ focused: true, tag: el.tagName.toLowerCase() });
})();
''';

  @override
  void dispose() {
    _urlController.dispose();
    _domChangedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    try {
      await _webViewControllerService.loadTarget(url);
      Logger.log('spike_harness: loadTarget($url) requested');
    } catch (e) {
      Logger.log('spike_harness: loadTarget failed: $e');
    }
  }

  Future<void> _readDom() async {
    final controller = _controller;
    if (controller == null) {
      Logger.log('spike_harness: readDom skipped, WebView not ready yet');
      return;
    }
    final result = await controller.evaluateJavascript(source: _readDomScript);
    final resultString = result?.toString() ?? '(null)';
    Logger.log('spike_harness: readDom result -> $resultString');
    setState(() => _lastResult = resultString);
  }

  Future<void> _readDomReal() async {
    try {
      final snapshot = await _webViewControllerService.readDom();
      final summary =
          'images=${snapshot.images.length} '
          '(withAlt=${snapshot.images.where((i) => i.hasAlt).length}) | '
          'searchCandidates=${snapshot.searchCandidates.length} | '
          'submitCandidates=${snapshot.submitCandidates.length} | '
          'labeledFields=${snapshot.labeledFields.length} | '
          'visibleText=${snapshot.visibleText.length} chars '
          '(truncated=${snapshot.truncated})';
      Logger.log('spike_harness: readDom() [real] -> $summary');
      setState(() => _lastResult = summary);
    } catch (e) {
      Logger.log('spike_harness: readDom() [real] failed: $e');
      setState(() => _lastResult = 'readDom() failed: $e');
    }
  }

  Future<void> _focusElement() async {
    final controller = _controller;
    if (controller == null) {
      Logger.log('spike_harness: focusElement skipped, WebView not ready yet');
      return;
    }
    final result = await controller.evaluateJavascript(
      source: _focusFirstInputScript,
    );
    final resultString = result?.toString() ?? '(null)';
    Logger.log('spike_harness: focusElement result -> $resultString');
    setState(() => _lastResult = resultString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spike harness (debug only)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(labelText: 'Target URL'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _load, child: const Text('Load')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _readDom,
                  child: const Text('Read DOM (inline, milestone01)'),
                ),
                ElevatedButton(
                  onPressed: _initialUserScripts == null ? null : _readDomReal,
                  child: const Text('Read DOM (real, milestone09-12)'),
                ),
                ElevatedButton(
                  onPressed: _focusElement,
                  child: const Text('Focus element'),
                ),
                Text('domChanged events: $_domChangedCount'),
              ],
            ),
          ),
          Expanded(
            child: _initialUserScripts == null
                ? const Center(child: CircularProgressIndicator())
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(_urlController.text)),
                    initialUserScripts: UnmodifiableListView(_initialUserScripts!),
                    onWebViewCreated: (controller) async {
                      _controller = controller;
                      // Registers webMessageListeners on the controller —
                      // see WebViewControllerService.attachController doc.
                      await _webViewControllerService.attachController(controller);
                    },
                    onLoadStop: (controller, url) {
                      _webViewControllerService.notifyLoadStop();
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 120,
              child: SingleChildScrollView(
                child: Text(
                  _lastResult,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
