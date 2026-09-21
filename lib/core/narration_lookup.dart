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
    "Press the button and say something like 'read this listing' or 'apply to this job'.",
    "Nhấn nút và nói ví dụ 'đọc tin tuyển dụng này' hoặc 'nộp đơn vào công việc này'.",
  );

  String get commandPrompt => _s(
    "Listening. Say something like 'read this listing' or 'apply to this job'.",
    "Đang nghe. Hãy nói ví dụ 'đọc tin tuyển dụng này' hoặc 'nộp đơn vào công việc này'.",
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

  // --- CAPTCHA (checkpoint 3) ------------------------------------------

  /// Verbatim from 01-intent.md section 4 (Vietnamese).
  String get captchaHandOff => _s(captchaHandOffEn, captchaHandOffVi);

  String get captchaAudioUsed => _s(
    'I used the CAPTCHA audio option.',
    'Đã dùng tùy chọn âm thanh cho CAPTCHA',
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
}
