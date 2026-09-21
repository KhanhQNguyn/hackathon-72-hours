import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/services/fuzzy_match_service.dart';

void main() {
  final fuzzy = FuzzyMatchService();

  group('milestone41 — FuzzyMatchService', () {
    test('cross-language values do NOT match (the AI fallback is needed)', () {
      expect(
        fuzzy.bestMatch('phone', ['Số điện thoại', 'Email', 'Tên']),
        isNull,
      );
    });

    test('tolerates a small typo / plural', () {
      expect(fuzzy.bestMatch('emails', ['Email', 'Tên', 'Địa chỉ']), 'Email');
    });

    test('ignores case, punctuation and Vietnamese diacritics', () {
      expect(fuzzy.bestMatch('ten', ['Email', 'Tên']), 'Tên');
      expect(fuzzy.bestMatch('EMAIL:', ['Email']), 'Email');
      expect(fuzzy.bestMatch('dia chi', ['Địa chỉ', 'Email']), 'Địa chỉ');
    });

    test('returns the closest of several plausible labels', () {
      expect(
        fuzzy.bestMatch('phone numbr', ['Phone number', 'Fax number']),
        'Phone number',
      );
    });

    test('empty value or empty candidates give null', () {
      expect(fuzzy.bestMatch('', ['Email']), isNull);
      expect(fuzzy.bestMatch('email', const []), isNull);
    });

    test('bestMatchAmong takes the first alternative that matches', () {
      expect(
        fuzzy.bestMatchAmong(['fone', 'phone', 'email'], ['Email', 'Phone']),
        'Phone',
      );
    });

    test('similarity: 1.0 for equal strings, 0.0 for disjoint ones', () {
      expect(FuzzyMatchService.similarity('abc', 'abc'), 1.0);
      expect(FuzzyMatchService.similarity('abc', 'xyz'), 0.0);
    });
  });
}
