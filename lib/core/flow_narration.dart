import 'language.dart';

/// Spoken (and on-screen) lines for the end-to-end flow, English and
/// Vietnamese. PLACEHOLDER WORDING for milestone 42, which owns the final
/// script — keep every flow string here so that milestone finds them in
/// one place.
class FlowNarration {
  final bool _vi;

  FlowNarration(String languageCode) : _vi = languageCode == AppLanguage.vi;

  String _t(String en, String vi) => _vi ? vi : en;

  String get commandPrompt => _t(
    'Listening. For example, say: read this job listing.',
    'Đang nghe. Ví dụ, hãy nói: đọc tin tuyển dụng này.',
  );

  String get loadingPage => _t('Opening the job page...', 'Đang mở trang tuyển dụng...');

  String get pageLoadFailed => _t(
    "That page didn't load as expected, retrying...",
    'Trang chưa tải được, đang thử lại...',
  );

  String get readingPage => _t('Reading the page...', 'Đang đọc trang...');

  String listingSummary({
    required String text,
    required int imagesWithoutAlt,
  }) {
    final images = imagesWithoutAlt == 0
        ? ''
        : _t(
            ' The page has $imagesWithoutAlt images without a text description.',
            ' Trang có $imagesWithoutAlt hình ảnh không có mô tả.',
          );
    return _t('Here is the listing: $text.$images', 'Nội dung tin tuyển dụng: $text.$images');
  }

  String get confirmListing => _t(
    'Is this the right listing? Say yes to continue.',
    'Đây có phải tin tuyển dụng bạn cần không? Nói có để tiếp tục.',
  );

  String get listingDeclined => _t('Okay, stopping here.', 'Được, tôi dừng lại ở đây.');

  String get readingForm => _t('Reading the application form...', 'Đang đọc mẫu đơn ứng tuyển...');

  String formText(String text) => _t('The application form says: $text', 'Mẫu đơn ghi: $text');

  String get pdfFailed => _t(
    "I couldn't read the application form.",
    'Tôi không đọc được mẫu đơn ứng tuyển.',
  );

  String offerSaved(String label, String value) => _t(
    '$label. Saved value: $value. Say yes to use it, or say a new value.',
    '$label. Giá trị đã lưu: $value. Nói có để dùng, hoặc nói giá trị mới.',
  );

  String askValue(String label) =>
      _t('$label. Please say your answer.', '$label. Hãy nói câu trả lời của bạn.');

  String confirmValue(String label, String value) => _t(
    'I heard $value for $label. Say yes to confirm, or no to say it again.',
    'Tôi nghe được $value cho $label. Nói có để xác nhận, hoặc không để nói lại.',
  );

  String filled(String label) => _t('$label filled in.', 'Đã điền $label.');

  String fillFailed(String label) => _t(
    "Couldn't fill in $label, trying again...",
    'Không điền được $label, đang thử lại...',
  );

  String cvChosen(String fileName) =>
      _t('CV file selected: $fileName', 'Đã chọn file CV: $fileName');

  String get cvNone =>
      _t('No CV file chosen, skipping it.', 'Chưa chọn file CV, bỏ qua mục này.');

  String finalReview(String summary) => _t(
    'Review: $summary. Say confirm to submit, or say edit followed by a field name.',
    'Xem lại: $summary. Nói xác nhận để nộp, hoặc nói sửa lại kèm tên mục.',
  );

  String get didNotUnderstand =>
      _t("Sorry, I didn't get that.", 'Xin lỗi, tôi chưa hiểu.');

  String noSuchField(String target) => _t(
    "I couldn't find a field called $target.",
    'Tôi không tìm thấy mục $target.',
  );

  String get submitting => _t('Submitting your application...', 'Đang nộp đơn ứng tuyển...');

  String get done => _t(
    'Your application has been submitted.',
    'Đơn ứng tuyển của bạn đã được nộp.',
  );

  String failure(String message) =>
      _t('Something went wrong: $message', 'Đã xảy ra lỗi: $message');
}
