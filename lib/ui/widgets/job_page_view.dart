import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../../services/webview_controller_service.dart';

/// The embedded WebView that hosts the real job page (milestone44).
///
/// `WebViewControllerService` has no view of its own: it needs this widget
/// in the tree, before a run starts, to hand it a controller
/// (`attachController`), the injected scripts, and the page-load signals
/// that `loadTarget()` waits on. Only used on a real run; mocked runs
/// have no page to show.
class JobPageView extends StatefulWidget {
  const JobPageView({super.key});

  @override
  State<JobPageView> createState() => _JobPageViewState();
}

class _JobPageViewState extends State<JobPageView> {
  List<UserScript>? _scripts;

  @override
  void initState() {
    super.initState();
    context.read<WebViewControllerService>().loadInitialUserScripts().then((
      scripts,
    ) {
      if (mounted) setState(() => _scripts = scripts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scripts = _scripts;
    if (scripts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final service = context.read<WebViewControllerService>();
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      initialUserScripts: UnmodifiableListView(scripts),
      onWebViewCreated: service.attachController,
      onLoadStop: (controller, url) => service.notifyLoadStop(),
      onReceivedError: (controller, request, error) {
        // Sub-resource failures (ads, trackers, images) are not page-load
        // failures — only the main frame counts (milestone22).
        if (request.isForMainFrame ?? false) {
          service.notifyLoadError(error.description);
        }
      },
    );
  }
}
