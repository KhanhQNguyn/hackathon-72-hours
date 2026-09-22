// Interprets short spoken replies (yes / no / continue / "edit FIELD") in
// English and Vietnamese. Deliberately simple keyword matching — replies
// are constrained by the prompts (spec.md §6.1). Milestones 39/41 (AI +
// fuzzy matching) can replace the field matching later.

const _affirmative = {
  'yes', 'yeah', 'yep', 'yup', 'ok', 'okay', 'sure', 'correct', 'right',
  'confirm', 'confirmed', 'submit', 'agree',
  // Vietnamese
  'có', 'vâng', 'dạ', 'đúng', 'được', 'ừ', 'đồng', 'xác',
};

const _negative = {
  'no', 'nope', 'nah', 'wrong', 'incorrect', 'change',
  // Vietnamese
  'không', 'khong', 'sai', 'khác', 'đừng',
};

const _editWords = {'edit', 'change', 'fix', 'correct', 'sửa', 'thay', 'đổi'};

const _fillerWords = {'lại', 'the', 'my', 'a', 'to', 'field', 'của', 'tôi', 'cái'};

List<String> _words(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .toList();

bool isNegative(String reply) => _words(reply).any(_negative.contains);

/// True for a "yes"-like reply. A reply containing a negative word is
/// never affirmative, even if it also contains one ("no, not okay").
bool isAffirmative(String reply) {
  if (isNegative(reply)) return false;
  return _words(reply).any(_affirmative.contains);
}

/// True for "retry" / "thử lại" — the voice retry after an error.
bool isRetry(String reply) {
  final text = reply.toLowerCase();
  return text.contains('retry') ||
      text.contains('try again') ||
      text.contains('thử lại') ||
      text.contains('thu lai');
}

/// True for "continue" / "tiếp tục" — the resume command after a CAPTCHA
/// hand-off (01-intent.md §4).
bool isContinue(String reply) {
  final text = reply.toLowerCase();
  return text.contains('continue') ||
      text.contains('tiếp tục') ||
      text.contains('tiep tuc');
}

/// If [reply] is an edit request ("edit phone", "sửa lại email"), returns
/// the named target with filler words removed (possibly empty); otherwise
/// null.
String? editTarget(String reply) {
  final words = _words(reply);
  if (words.isEmpty || !_editWords.contains(words.first)) return null;
  return words.skip(1).where((w) => !_fillerWords.contains(w)).join(' ');
}

/// Words shared between [a] and [b], used to match a spoken field name to
/// a detected field label.
int sharedWordCount(String a, String b) {
  final wa = _words(a).toSet();
  return _words(b).where(wa.contains).length;
}

/// Canned "what the user says" half of the standalone scripted scenario
/// demo (debug-only, see `lib/mocks/scripted_demo_flow.dart`) — recited
/// verbatim in the on-screen/log transcript alongside each narrated line,
/// never parsed or acted on. `narration_lookup.dart`'s new `demo*`
/// getters are the "what the AI says" half of the same script.
const List<String> scenarioDemoUserReplies = [
  'Software Engineer on VietNamWorks website.',
  'Yes', // confirm listing
  'I want Embedded Software Engineer role',
  'Yes', // confirm apply
  'No', // decline the upsell
  'Yes', // First name
  'Yes', // Last name
  'Yes', // Job title
  'Yes', // Current job level
  'Yes', // Years of experience
  'Yes', // Highest Education
  'Yes', // Current job function
  'Yes', // Current industry
  'No', // decline to fill in the missing Current salary field
  'Yes', // Cell number
  'Yes', // Date of birth
  'Yes', // Nationality
  'Yes', // Gender
  'Yes', // Marital Status
  'Yes', // Country
  'Yes', // Address
  'Yes', // Expect location
  'Skip', // expected benefits (optional)
  '10000', // expected salary (compulsory)
  'Yes', // Expected job level
  'Yes', // show expected salary to employer toggle
  'Yes', // Expected job function
  'Yes', // Expected Industry
  'Yes', // agree to the privacy policy
  'I want to change Job title to Embedded Engineer', // edit request after box ticked
  'Confirm', // final submit
];
