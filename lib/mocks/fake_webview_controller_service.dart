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
  Future<bool> clickElement(String nodeId) async => true;

  @override
  Future<String?> getFileInputName(String nodeId) async => 'cv.pdf';

  @override
  Future<void> focusElement(String nodeRef) async {}

  @override
  Future<String?> locateSearchSubmitButton() async => 'n-search-submit';

  @override
  Future<List<JobResultCard>> getResultCards() async => cannedResultCards;

  @override
  Future<bool> dismissApplyUpsell() async => false;

  @override
  Future<bool> detectApplySuccess() async => true;

  @override
  Future<void> highlightElement(String nodeId) async {}

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
        'Embedded Software Engineer (Flash Boot Loader) at Hella Vietnam Requirements: Job description' 
        'Your Tasks'
        'In the business division Electronics, you will be working with the software development team for electronics control units.'
        'Design, develop & test product-specific software of automotive electronics module & system over the entire product development cycle;'
        'Work on SW-architecture, write, test and debug code according to software requirement specification and the defined process;'
        'Discuss with customer about specific solution for electronics modules & system, including function implementation and system interface;'
        'Complete software module test report and integration test report according to test result;'
        'Primarily responsible of software modules of HELLA products;'
        'Other job assigned by Department Manager. '
        'Job requirements'
        ' How well do you fit this job and rank among other candidates?'
        'Minimum bachelor degree in computer science, engineering, or related field.'

        '2-5 years experience in Embedded System.'

        'Embedded development tool especially Rhapsody, Polyspace, WindIdea, Davinci, DOORs, PTC…'

        'Be proficient with C programming language, firmware, bare-metal programming.'

        'Be familiar with embedded microcontroller 16-/32-bit microprocessor is a plus.'

        'Write and review Software specifications, Architecture and Design documents for the system.'

        'Experience with simulation and development tools, e.g. Vector CANoe, etc'

        'Real time operating system OSEK programming experience preferred'

        'Knowledge on Communication & Diagnostic protocols: CAN, LIN, Ethernet and TCP/IP protocols and UDS.'
        'Required Skills'

        'Knowledge and skills related to AUTOSAR, CAN, MEM, UDS, RTOS.'

        'Nice to have experience with Flash BootLoader'

        'Good communication in English and presentation skills.'

        'Familiarity with Agile methodology is an advantage.'

        'Our Offer'
        'Clear development and qualification path in our consulting organization'
        'International working environment'
        'The involvement of the entire project development of HELLA products'
        'Attractive benefits with healthcare insurances, HELLA activities for employees,...'
        'International trainings in HELLA facilities (if needed)'

        'Our Benefits'
        'Guaranteed 13th month salary'
        'Performance bonus'
        'Service bonus of 1-month salary after 2 years working with HELLA'
        'Lunch and mobile allowance…',
    truncated: false,
  );

  /// A plausible VietnamWorks-style results page for the search_job flow.
  static const List<JobResultCard> cannedResultCards = [
    JobResultCard(
      elementId: 'n-card-0',
      title: 'Embedded Software Engineer (Flash Boot Loader)',
      company: 'Hella Vietnam',
      location: 'Ho Chi Minh',
    ),
    JobResultCard(
      elementId: 'n-card-1',
      title: 'Automotive Diagnostic Software Engineer',
      company: 'Bosch Global Software Technology',
      location: 'Ha Noi',
    ),
    JobResultCard(
      elementId: 'n-card-2',
      title: 'C++ Developer',
      company: 'FPT Software',
      location: 'Ha Noi',
    ),
    JobResultCard(
      elementId: 'n-card-3',
      title: 'Senior Software Engineer',
      company: 'Home Credit Vietnam',
      location: 'Ho Chi Minh',
    ),
    JobResultCard(
      elementId: 'n-card-4',
      title: 'Software Developer (Fresher and Junior)',
      company: 'Netcompany',
      location: 'Ho Chi Minh',
    ),
  ];
}
