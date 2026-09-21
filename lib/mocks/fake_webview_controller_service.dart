import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/captcha_check_result.dart';
import '../models/dom_snapshot.dart';
import '../models/fill_field_result.dart';
import '../services/webview_controller_service.dart';

/// Canned-content stand-in for `WebViewControllerService` so the FSM/UI
/// can be exercised end-to-end without a real WebView (milestone34,
/// plan.md B1/B5).
///
/// `noSuchMethod` means members added to the real service by other
/// workstreams don't break this fake's compilation; calling one of them
/// throws instead of returning a silent null.
class FakeWebViewControllerService implements WebViewControllerService {
  final StreamController<void> _domChanged = StreamController<void>.broadcast();

  @override
  Stream<void> get domChangedEvents => _domChanged.stream;

  @override
  Future<List<UserScript>> loadInitialUserScripts() async => const [];

  @override
  void notifyLoadStop() => _domChanged.add(null);

  @override
  Future<void> attachController(InAppWebViewController controller) async {}

  @override
  Future<void> loadTarget(String url) async {}

  @override
  Future<DomSnapshot> readDom() async => cannedSnapshot;

  @override
  void notifyLoadError(String description) {}

  @override
  Future<CaptchaCheckResult> detectCaptcha() async =>
      const CaptchaCheckResult(detected: false);

  @override
  Future<bool> tryResolveCaptchaViaAudio() async => false;

  @override
  Future<FillFieldResult> fillField(String nodeId, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const FillFieldResult(success: true);
  }

  @override
  Future<bool> triggerFileChooser(String nodeId) async => true;

  @override
  Future<void> focusElement(String nodeRef) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeWebViewControllerService: ${invocation.memberName} not faked yet',
  );

  /// A plausible job-application page: a few images, one search field, one
  /// submit button, and four labeled fields matching the applicant-profile
  /// shape (name, phone, email, CV upload).
  static const DomSnapshot cannedSnapshot = DomSnapshot(
    images: [
      DomImage(src: 'https://example.test/job-description.png', hasAlt: false),
      DomImage(
        src: 'https://example.test/logo.png',
        altText: 'Example Co logo',
        hasAlt: true,
      ),
      DomImage(
        src: 'https://example.test/banner.png',
        altText: '',
        hasAlt: false,
      ),
    ],
    searchCandidates: [
      DomFormField(
        elementId: 'n-search',
        tag: 'input',
        type: 'search',
        role: 'search',
        placeholder: 'Search jobs',
        heuristicScore: 9,
      ),
    ],
    submitCandidates: [
      DomFormField(
        elementId: 'n-submit',
        tag: 'button',
        type: 'submit',
        role: 'submit',
        ariaLabel: 'Submit application',
        heuristicScore: 8,
      ),
    ],
    labeledFields: [
      DomFormField(
        elementId: 'n-name',
        tag: 'input',
        type: 'text',
        resolvedLabel: 'Full name',
        labelSource: 'label_for',
      ),
      DomFormField(
        elementId: 'n-phone',
        tag: 'input',
        type: 'tel',
        resolvedLabel: 'Phone number',
        labelSource: 'label_for',
      ),
      DomFormField(
        elementId: 'n-email',
        tag: 'input',
        type: 'email',
        resolvedLabel: 'Email',
        labelSource: 'label_for',
      ),
      DomFormField(
        elementId: 'n-cv',
        tag: 'input',
        type: 'file',
        resolvedLabel: 'Upload CV',
        labelSource: 'label_for',
      ),
    ],
    visibleText:
        'Senior Flutter Developer at Example Co. Requirements: 3+ years '
        'Flutter, REST APIs. How to apply: fill in the form below.',
    truncated: false,
  );
}
