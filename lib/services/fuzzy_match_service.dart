import 'dart:math' as math;

import '../core/constants.dart';

/// Matches STT text / saved applicant-profile values against detected
/// form-field labels by string similarity, before falling back to the
/// OpenAI matching call (milestone41). First line of defense against
/// transcription distortion and label-text variance across sites; it does
/// NOT bridge languages ("phone" vs "Số điện thoại") — that is exactly
/// when the AI fallback is needed, so a non-match returns `null`. See
/// spec.md §6.1, §6 and plan.md C2.
class FuzzyMatchService {
  FuzzyMatchService({this.threshold = AppConstants.fuzzyMatchThreshold});

  final double threshold;

  /// The candidate label most similar to [value], or `null` if none
  /// reaches [threshold]. Case, punctuation and Vietnamese diacritics are
  /// ignored for comparison; the original label is returned.
  String? bestMatch(String value, List<String> candidateLabels) {
    final target = _normalize(value);
    if (target.isEmpty) return null;

    String? best;
    var bestScore = 0.0;
    for (final label in candidateLabels) {
      final score = similarity(target, _normalize(label));
      if (score > bestScore) {
        best = label;
        bestScore = score;
      }
    }
    return bestScore >= threshold ? best : null;
  }

  /// Tries each alternative in order (e.g. STT n-best) and returns the
  /// first that matches a label.
  String? bestMatchAmong(List<String> values, List<String> candidateLabels) {
    for (final v in values) {
      final match = bestMatch(v, candidateLabels);
      if (match != null) return match;
    }
    return null;
  }

  /// The candidate whose normalized words overlap [reply]'s the most,
  /// requiring at least [minSharedWords]. Suited for matching a full
  /// spoken sentence (e.g. "I choose X at Y in Z") against a short
  /// candidate label — [bestMatch]'s whole-string edit distance scores
  /// poorly there since the sentence is much longer than any one label
  /// (real-target demo flow, item C: picking a job card by voice).
  String? bestMatchByWordOverlap(
    String reply,
    List<String> candidateLabels, {
    int minSharedWords = 2,
  }) {
    final replyWords = _normalize(
      reply,
    ).split(' ').where((w) => w.length > 1).toSet();
    if (replyWords.isEmpty) return null;

    String? best;
    var bestScore = 0;
    for (final label in candidateLabels) {
      final labelWords = _normalize(
        label,
      ).split(' ').where((w) => w.length > 1);
      final score = labelWords.where(replyWords.contains).length;
      if (score > bestScore) {
        best = label;
        bestScore = score;
      }
    }
    return bestScore >= minSharedWords ? best : null;
  }

  /// Lowercased, diacritic-folded, punctuation-stripped form of [text]
  /// (public wrapper around the same normalization [bestMatch] uses
  /// internally) — reused by the real-target demo flow to build a
  /// VietnamWorks results-URL slug consistently with how fields/labels
  /// are already compared elsewhere in this service.
  static String normalize(String text) => _normalize(text);

  /// Levenshtein similarity ratio in [0, 1]: `1 - distance / longer`.
  static double similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final longest = math.max(a.length, b.length);
    if (longest == 0) return 1.0;
    return 1.0 - _levenshtein(a, b) / longest;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  static const String _withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  static const String _folded =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static String _normalize(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final idx = _withDiacritics.indexOf(ch);
      if (idx >= 0) {
        buffer.write(_folded[idx]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else if (RegExp(r'\s').hasMatch(ch)) {
        buffer.write(' ');
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
