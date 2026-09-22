import '../models/job_listing.dart';
import '../orchestration/application_flow_state.dart';
import 'language.dart';

// Every user-facing spoken / on-screen line of the flow lives in this
// file, in English and Vietnamese (milestones 26 and 42, plan.md C3).
//
// Two strings are fixed verbatim by other documents and must not be
// rephrased:
//  - the CAPTCHA hand-off (01-intent.md section 4), Vietnamese form
//  - the page-load retry line (02-spec.md section 3), English form
//
// The Vietnamese wording still needs review by a fluent speaker on the
// team before the final recording (milestone 42 Definition of Done).

/// Exact CAPTCHA hand-off narration, Vietnamese (01-intent.md section 4).
const String captchaHandOffVi =
    "Có CAPTCHA ở đây, bạn giải giúp tôi rồi nói 'tiếp tục' nhé";

/// English counterpart of [captchaHandOffVi].
const String captchaHandOffEn =
    "There's a CAPTCHA here, please solve it and say 'continue'";

/// Exact retry narration, English (02-spec.md section 3).
const String pageRetryEn = "that didn't load as expected, retrying...";

const String pageRetryVi = 'trang chưa tải như mong đợi, đang thử lại...';

bool _isVi(String languageCode) => languageCode == AppLanguage.vi;

String _t(String languageCode, String en, String vi) =>
    _isVi(languageCode) ? vi : en;

/// On-screen text for an FSM state, shown until the flow speaks its first
/// line and used as the fallback description of "where we are".
String narrationFor(
  ApplicationFlowState state, {
  String language = AppLanguage.en,
}) {
  final n = FlowNarration(language);
  if (state is IdleState) return n.idlePrompt;
  if (state is ListeningState) return n.commandPrompt;
  if (state is ParsingIntentState) return n.parsingIntent;
  if (state is LoadingTargetState) return n.loadingPage;
  if (state is ReadingContentState) return n.readingPage;
  if (state is AwaitingUserActionState) return n.confirmListing;
  if (state is FillingFormState) return n.fillingField(state.currentFieldId);
  if (state is FinalReviewState) return n.reviewHeading;
  if (state is EditingFieldState) return n.editingField(state.fieldId);
  if (state is AwaitingSubmitConfirmationState) return n.submitting;
  if (state is DoneState) return n.done;
  if (state is RetryingState) return n.pageRetrying;
  if (state is ErrorState) return n.failure(state.message);
  if (state is CaptchaPendingState) return n.captchaHandOff;
  return n.working;
}

/// Spoken when STT confidence is below threshold, or the intent could not
/// be understood (milestones 29 and 36). Wording fixed by milestone 29.
String repromptMessage(String languageCode) => _t(
  languageCode,
  "Sorry, I didn't catch that, could you repeat?",
  'Xin lỗi, tôi chưa nghe rõ, bạn nói lại được không?',
);

/// Spoken when the recognizer can't be used at all.
String speechUnavailableMessage(String languageCode) => _t(
  languageCode,
  'Speech recognition is unavailable. Please check the microphone permission.',
  'Không thể sử dụng nhận dạng giọng nói. Hãy kiểm tra quyền micro.',
);

/// Every line the flow speaks, for one language.
class FlowNarration {
  FlowNarration(this.languageCode);

  final String languageCode;

  String _s(String en, String vi) => _t(languageCode, en, vi);

  // --- state prompts --------------------------------------------------

  String get idlePrompt => _s(
    "Press the button and say which job do you want to search for ?",
    "Hãy nhấn nút và nói công việc bạn muốn tìm kiếm.",
  );

  String get commandPrompt => _s(
    "Listening. What job would you like to search for ?",
    "Đang nghe. Bạn muốn tìm công việc nào?",
  );

  String get parsingIntent =>
      _s('Understanding your request...', 'Đang hiểu yêu cầu của bạn...');

  String get loadingPage =>
      _s('Opening the job page...', 'Đang mở trang tuyển dụng...');

  String get readingPage =>
      _s('Reading the job description...', 'Đang đọc mô tả công việc...');

  String get working => _s('Working...', 'Đang xử lý...');

  // --- retry / error --------------------------------------------------

  /// Verbatim from 02-spec.md section 3 (English).
  String get pageRetrying => _s(pageRetryEn, pageRetryVi);

  String get pageLoadFailed => pageRetrying;

  String failure(String message) =>
      _s('Something went wrong: $message', 'Đã xảy ra lỗi: $message');

  /// Spoken after an error: how to retry by voice (audit 1.6b).
  String get retryPrompt => _s(
    "Say 'retry' to try again, or press the button to start over.",
    "Nói 'thử lại' để thử lại, hoặc nhấn nút để bắt đầu lại.",
  );

  // Error messages carried by `ErrorState` — kept here so a Vietnamese
  // user never hears an English sentence inside `failure(...)`.
  String get errPageLoad =>
      _s('The page did not load.', 'Trang không tải được.');
  String get errAiUnavailable => _s(
    "Couldn't reach the AI service.",
    'Không kết nối được dịch vụ AI.',
  );
  String get errNoRequest =>
      _s("Couldn't understand the request.", 'Tôi không hiểu yêu cầu.');
  String get errVoice => _s(
    "Couldn't understand the voice command.",
    'Tôi không hiểu lệnh giọng nói.',
  );
  String get errSpeechUnavailable => _s(
    'Speech recognition is unavailable.',
    'Không dùng được nhận dạng giọng nói.',
  );
  String get errNoListingReply => _s(
    'No response to the listing question.',
    'Không nhận được câu trả lời về tin tuyển dụng.',
  );
  String get errNoReviewReply => _s(
    'No response at the final review.',
    'Không nhận được câu trả lời ở bước xem lại.',
  );
  String get errCaptcha =>
      _s('The CAPTCHA was not resolved.', 'CAPTCHA chưa được giải.');
  String errNoAnswer(String label) =>
      _s('No answer was given for $label.', 'Chưa có câu trả lời cho $label.');
  String errFill(String label) =>
      _s("Couldn't fill in $label.", 'Không điền được $label.');
  String get errSubmitNoButton => _s(
    'No submit button was found on the page.',
    'Không tìm thấy nút nộp đơn trên trang.',
  );
  String get errSubmitUnsure => _s(
    'Not sure which button submits the application.',
    'Không chắc nút nào dùng để nộp đơn.',
  );
  String get errSubmitClick => _s(
    'The submit button could not be clicked.',
    'Không nhấn được nút nộp đơn.',
  );
  String get errUnexpected =>
      _s('An unexpected problem occurred.', 'Đã xảy ra sự cố không mong muốn.');

  // --- microphone cues and labels (audit: mic UX) ----------------------

  String get micLabelIdle =>
      _s('Start voice command', 'Bắt đầu ra lệnh bằng giọng nói');
  String get micLabelListening => _s('Listening…', 'Đang nghe…');

  /// Spoken just before the recognizer opens.
  String get micCueStart => _s('Listening', 'Đang nghe');

  /// Spoken when speech was captured; on silence the spoken re-prompt is
  /// the stop cue.
  String get micCueStop => _s('Got it', 'Đã nghe rõ');

  // --- home / platform ---------------------------------------------------

  String get settingsButton => _s('Settings', 'Cài đặt');

  String get unsupportedPlatform => _s(
    'This app is designed for Android — please run on an Android device.',
    'Ứng dụng này được thiết kế cho Android — hãy chạy trên thiết bị Android.',
  );

  // --- CAPTCHA (checkpoint 3) ------------------------------------------

  /// Verbatim from 01-intent.md section 4 (Vietnamese).
  String get captchaHandOff => _s(captchaHandOffEn, captchaHandOffVi);

  /// The audio button was pressed; the challenge still has to be solved by
  /// the user, so this is a hand-off too (audit 1.5).
  String get captchaAudioOpened => _s(
    "I opened the CAPTCHA's audio option. Listen, enter the code, then say 'continue'.",
    "Tôi đã mở tùy chọn âm thanh của CAPTCHA. Hãy nghe, nhập mã, rồi nói 'tiếp tục'.",
  );

  // --- reading the listing ----------------------------------------------

  String listingSummary({
    required String text,
    required int imagesWithoutAlt,
  }) {
    final images = imagesWithoutAlt == 0
        ? ''
        : _s(
            ' The page has $imagesWithoutAlt images without a text description.',
            ' Trang có $imagesWithoutAlt hình ảnh không có mô tả.',
          );
    return _s(
      'Here is the listing: $text.$images',
      'Nội dung tin tuyển dụng: $text.$images',
    );
  }

  /// Spoken from the AI-extracted listing (milestone 38).
  String listingFromAi(JobListing l) {
    final parts = <String>[
      if (l.title.isNotEmpty && l.company.isNotEmpty)
        _s('${l.title} at ${l.company}.', '${l.title} tại ${l.company}.')
      else if (l.title.isNotEmpty)
        '${l.title}.',
      if (l.requirements.isNotEmpty)
        _s('Requirements: ${l.requirements}.', 'Yêu cầu: ${l.requirements}.'),
      if (l.howToApply.isNotEmpty)
        _s(
          'How to apply: ${l.howToApply}.',
          'Cách ứng tuyển: ${l.howToApply}.',
        ),
    ];
    return parts.join(' ');
  }

  /// Text found inside an image that had no alt text (milestone 37).
  String imageTranscript(String text) => _s(
    'An image on the page says: $text',
    'Một hình ảnh trên trang ghi: $text',
  );

  String get confirmListing => _s(
    'Is this the right listing? Say yes to continue.',
    'Đây có phải tin tuyển dụng bạn cần không? Nói có để tiếp tục.',
  );

  String get listingDeclined =>
      _s('Okay, stopping here.', 'Được, tôi dừng lại ở đây.');

  // --- the application form ----------------------------------------------

  String get readingForm =>
      _s('Reading the application form...', 'Đang đọc mẫu đơn ứng tuyển...');

  String formText(String text) =>
      _s('The application form says: $text', 'Mẫu đơn ghi: $text');

  String formSection(String heading, String body) =>
      heading.isEmpty ? body : '$heading. $body';

  String get pdfFailed => _s(
    "I couldn't read the application form.",
    'Tôi không đọc được mẫu đơn ứng tuyển.',
  );

  String get chooseFormPdf => _s(
    'Please choose the application form PDF.',
    'Hãy chọn tệp PDF mẫu đơn ứng tuyển.',
  );

  String get noFormPdf => _s(
    'No form file chosen. Continuing with the fields on the page.',
    'Chưa chọn mẫu đơn. Tiếp tục với các mục trên trang.',
  );

  // --- per-field confirm loop --------------------------------------------

  /// "Filling in your {fieldLabel}..." (milestone 42).
  String fillingField(String label) =>
      _s('Filling in your $label...', 'Đang điền $label của bạn...');

  String editingField(String label) =>
      _s('Editing $label...', 'Đang sửa $label...');

  String offerSaved(String label, String value) => _s(
    '$label. Saved value: $value. Say yes to use it, or say a new value.',
    '$label. Giá trị đã lưu: $value. Nói có để dùng, hoặc nói giá trị mới.',
  );

  String askValue(String label) => _s(
    '$label. Please say your answer.',
    '$label. Hãy nói câu trả lời của bạn.',
  );

  String confirmValue(String label, String value) => _s(
    'I heard $value for $label. Say yes to confirm, or no to say it again.',
    'Tôi nghe được $value cho $label. Nói có để xác nhận, hoặc không để nói lại.',
  );

  String fillFailed(String label) => _s(
    "Couldn't fill in $label, trying again...",
    'Không điền được $label, đang thử lại...',
  );

  String cvChosen(String fileName) =>
      _s('CV file selected: $fileName', 'Đã chọn file CV: $fileName');

  String get cvNone => _s(
    'No CV file chosen, skipping it.',
    'Chưa chọn file CV, bỏ qua mục này.',
  );

  /// Spoken BEFORE the page's own file chooser opens: a blind user must
  /// not land in an unannounced system picker. The page cannot be given
  /// the CV saved in Settings (browsers block that), so the user picks it
  /// again here (audit 1.4b).
  String get cvChooserAnnouncement => _s(
    "This form needs your CV file. Your phone's file picker will open now. Choose your CV file again; it will return to the app when you're done.",
    'Mẫu này cần file CV của bạn. Trình chọn tệp của điện thoại sẽ mở ngay bây giờ. Hãy chọn lại file CV; sau đó ứng dụng sẽ tự quay lại.',
  );

  String get cvNotAttached => _s(
    'No CV file was attached, skipping it.',
    'Chưa có file CV nào được đính kèm, bỏ qua mục này.',
  );

  /// Milestone 24: the form has no field for something the flow needs.
  String fieldNotFound(String target) => _s(
    "This form doesn't seem to have a field for $target — skipping it",
    'Mẫu này dường như không có mục $target — bỏ qua mục này',
  );

  // --- final review / submit ----------------------------------------------

  String get reviewHeading =>
      _s('Review your application.', 'Xem lại đơn ứng tuyển của bạn.');

  String finalReview(String summary) => _s(
    'Review: $summary. Say confirm to submit, or say edit followed by a field name.',
    'Xem lại: $summary. Nói xác nhận để nộp, hoặc nói sửa lại kèm tên mục.',
  );

  String get didNotUnderstand =>
      _s("Sorry, I didn't get that.", 'Xin lỗi, tôi chưa hiểu.');

  String noSuchField(String target) => _s(
    "I couldn't find a field called $target.",
    'Tôi không tìm thấy mục $target.',
  );

  /// Element-match disambiguation (milestone 39, spec.md section 6).
  String disambiguate(List<String> labels) {
    final quoted = labels.map((l) => "'$l'").toList();
    final head = quoted.sublist(0, quoted.length > 1 ? quoted.length - 1 : 0);
    final joined = quoted.length <= 1
        ? quoted.join()
        : _s(
            '${head.join(', ')} and ${quoted.last}',
            '${head.join(', ')} và ${quoted.last}',
          );
    return _s(
      'I see more than one field that could match: $joined. Which one did you mean?',
      'Tôi thấy có nhiều mục có thể phù hợp: $joined. Bạn muốn mục nào?',
    );
  }

  String get submitting =>
      _s('Submitting your application...', 'Đang nộp đơn ứng tuyển...');

  String get done => _s(
    'Your application has been submitted.',
    'Đơn ứng tuyển của bạn đã được nộp.',
  );

  // --- navigation (Feature 2) --------------------------------------------

  String get navigateUnsupported => _s(
    'Moving around the page by voice is not available yet.',
    'Chức năng di chuyển trên trang bằng giọng nói chưa có.',
  );

  // --- real-target demo flow: search VietnamWorks (item A/B/C/E/F) -------

  String searchingFor(String query) => _s(
    'Searching VietnamWorks for $query...',
    'Đang tìm $query trên VietnamWorks...',
  );

  String get searchBarLabel => _s('Search bar', 'Thanh tìm kiếm');

  String get noResultsFound => _s(
    "I couldn't find any job listings for that search.",
    'Tôi không tìm thấy tin tuyển dụng nào cho tìm kiếm đó.',
  );

  String resultsFound(int count) => _s(
    'I found $count job listings. Let me read them to you.',
    'Tôi tìm thấy $count tin tuyển dụng. Để tôi đọc cho bạn nghe.',
  );

  String resultCardLabel(int index, String title, String company, String location) {
    final where = [
      if (company.isNotEmpty) company,
      if (location.isNotEmpty) location,
    ].join(', ');
    return _s(
      'Result $index: $title${where.isEmpty ? '' : ' at $where'}.',
      'Kết quả $index: $title${where.isEmpty ? '' : ' tại $where'}.',
    );
  }

  String get whichResult => _s(
    'Which one would you like? You can say the job title or company.',
    'Bạn muốn công việc nào? Bạn có thể nói tên công việc hoặc tên công ty.',
  );

  String get noMatchingResult => _s(
    "I couldn't match that to any of the listings. Could you say the job title or company again?",
    'Tôi không khớp được với tin tuyển dụng nào. Bạn nói lại tên công việc hoặc tên công ty được không?',
  );

  String confirmApply(String title) => _s(
    'Do you want to apply to $title? Say yes to continue.',
    'Bạn có muốn ứng tuyển vào $title không? Nói có để tiếp tục.',
  );

  String get applyButtonLabel => _s('Apply button', 'Nút ứng tuyển');

  String get submitButtonLabel => _s('Submit button', 'Nút nộp đơn');

  String get openingApplyForm => _s(
    'Opening the application form...',
    'Đang mở mẫu đơn ứng tuyển...',
  );

  String get applyFormNotFound => _s(
    "I couldn't open the application form for this job.",
    'Tôi không mở được mẫu đơn ứng tuyển cho công việc này.',
  );

  /// Spoken instead of [done] when the submit click succeeded but
  /// [WebViewControllerService.detectApplySuccess] never confirmed it
  /// within the polling window (item F) — the flow must not claim
  /// success it couldn't verify.
  String get submitUnconfirmed => _s(
    "I clicked submit, but I couldn't confirm your application actually went through. Please check the page.",
    'Tôi đã nhấn nộp đơn, nhưng không xác nhận được đơn đã được gửi thành công. Hãy kiểm tra lại trang.',
  );

  // --- standalone scripted scenario demo (debug-only) ---------------------
  //
  // A literal, pre-written "play script" for `lib/mocks/scripted_demo_flow.dart`
  // — recited verbatim, not derived from any real DOM/AI logic. Lines that
  // already exist verbatim elsewhere in this class (commandPrompt,
  // parsingIntent, resultsFound, confirmListing, whichResult, loadingPage,
  // readingPage, working, confirmApply, readingForm, submitting, done) are
  // reused as-is by the demo script rather than duplicated here.

  String demoSearching(String query) =>
      _s('Searching VietnamWorks for $query', 'Đang tìm $query trên VietnamWorks');

  String get demoPdfFound => _s(
    'I found a PDF description format, let me download and analyze it.',
    'Tôi thấy mô tả công việc ở định dạng PDF, để tôi tải xuống và phân tích.',
  );

  String get demoJobDescriptionIntro =>
      _s('Here is the job description', 'Đây là mô tả công việc');

  /// The full Embedded Software Engineer PDF-style description, spoken
  /// verbatim as one utterance — left in English in both language modes
  /// since it's quoted third-party job-posting content, not app UI text.
  String get demoJobDescriptionText =>
      'Your Tasks. '
      'In the business division Electronics, you will be working with the software development team for electronics control units. '
      'Design, develop and test product-specific software of automotive electronics module and system over the entire product development cycle. '
      'Work on SW-architecture, write, test and debug code according to software requirement specification and the defined process. '
      'Discuss with customer about specific solution for electronics modules and system, including function implementation and system interface. '
      'Complete software module test report and integration test report according to test result. '
      'Primarily responsible of software modules of HELLA products. '
      'Other job assigned by Department Manager. '
      'Job requirements. How well do you fit this job and rank among other candidates? '
      'Minimum bachelor degree in computer science, engineering, or related field. '
      '2 to 5 years experience in Embedded System. '
      'Embedded development tool especially Rhapsody, Polyspace, WindIdea, Davinci, DOORs, PTC. '
      'Be proficient with C programming language, firmware, bare-metal programming. '
      'Be familiar with embedded microcontroller 16 or 32-bit microprocessor is a plus. '
      'Write and review Software specifications, Architecture and Design documents for the system. '
      'Experience with simulation and development tools, e.g. Vector CANoe, etc. '
      'Real time operating system OSEK programming experience preferred. '
      'Knowledge on Communication and Diagnostic protocols: CAN, LIN, Ethernet and TCP/IP protocols and UDS. '
      'Required Skills. Knowledge and skills related to AUTOSAR, CAN, MEM, UDS, RTOS. '
      'Nice to have experience with Flash BootLoader. '
      'Good communication in English and presentation skills. '
      'Familiarity with Agile methodology is an advantage. '
      'Our Offer. Clear development and qualification path in our consulting organization. '
      'International working environment. '
      'The involvement of the entire project development of HELLA products. '
      'Attractive benefits with healthcare insurances, HELLA activities for employees. '
      'International trainings in HELLA facilities if needed. '
      'Our Benefits. Guaranteed 13th month salary. '
      'Performance bonus. '
      'Service bonus of 1 month salary after 2 years working with HELLA. '
      'Lunch and mobile allowance.';

  String get demoUpsellPrompt => _s(
    'Do you want to maximize competitive advantage before applying?',
    'Bạn có muốn tối ưu hồ sơ để tăng lợi thế cạnh tranh trước khi ứng tuyển không?',
  );

  String demoCvAutoAttach(String fileName) => _s(
    'This form needs your CV file. I will take your CV uploaded in the settings $fileName to put it in the form.',
    'Mẫu này cần file CV của bạn. Tôi sẽ lấy file CV $fileName bạn đã tải lên trong cài đặt để đính kèm vào mẫu đơn.',
  );

  String get demoCvUploaded => _s('CV file uploaded.', 'Đã tải file CV lên.');

  /// The uniform per-field pattern: "Label: value. Say yes to confirm or
  /// edit the field."
  String demoFieldConfirm(String label, String value) => _s(
    '$label: $value. Say yes to confirm or edit the field.',
    '$label: $value. Nói có để xác nhận hoặc sửa lại mục này.',
  );

  /// A section header spoken plainly, e.g. "Working preference".
  String demoSection(String title) => title;

  /// A field the form left blank, offering to fill it in.
  String demoFieldMissing(String label) => _s(
    '$label: Missing. Do you want to fill in?',
    '$label: Còn thiếu. Bạn có muốn điền vào không?',
  );

  String demoOptionalMultiChoice(String label) => _s(
    '$label (optional): what do you want to choose or skip?',
    '$label (không bắt buộc): bạn muốn chọn gì, hay bỏ qua?',
  );

  String get demoExpectedSalaryPrompt => _s(
    'Expected salary in USD (compulsory): what is your expected salary?',
    'Mức lương mong muốn bằng USD (bắt buộc): bạn mong muốn mức lương bao nhiêu?',
  );

  String get demoShowSalaryToggle => _s(
    'Do you want to show your expected salary to employer? Say yes to confirm or edit the field.',
    'Bạn có muốn hiển thị mức lương mong muốn cho nhà tuyển dụng không? Nói có để xác nhận hoặc sửa lại mục này.',
  );

  String get demoPrivacyPolicyPrompt => _s(
    'Do you agree to the Privacy Policy of this employer?',
    'Bạn có đồng ý với Chính sách bảo mật của nhà tuyển dụng này không?',
  );

  String get demoBoxTicked => _s(
    'Box ticked. Say confirm to submit, or say edit followed by a field name.',
    'Đã đánh dấu ô. Nói xác nhận để nộp đơn, hoặc nói sửa lại kèm tên mục.',
  );

  /// The edit-loop-back confirmation after a spoken "change X to Y"
  /// request, mirroring the real flow's edit mechanism but recited
  /// verbatim for the scripted demo.
  String demoFieldChanged(String label, String newValue) => _s(
    'Your $label have been changed to $newValue',
    '$label của bạn đã được đổi thành $newValue',
  );

  /// The shorter re-prompt after an edit, without the "Box ticked." prefix
  /// (the box was already ticked before the edit interrupted the flow).
  String get demoConfirmOrEditPrompt => _s(
    'Say confirm to submit, or say edit followed by a field name.',
    'Nói xác nhận để nộp đơn, hoặc nói sửa lại kèm tên mục.',
  );
}
