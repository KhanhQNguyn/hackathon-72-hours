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
