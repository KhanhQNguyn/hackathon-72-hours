import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/models/openai_results.dart';
import 'package:job_access_assist/models/pdf_form_field.dart';
import 'package:job_access_assist/services/openai_service.dart';

// Milestones 36-40. These verify the request shape, response parsing and
// the confidence/validity guards against a scripted HTTP client. They do
// NOT prove the prompts behave well against the real model, which needs a
// live key (each milestone's "against the real API" Definition of Done).

http.Response _reply(Object content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': jsonEncode(content)},
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

OpenAiService _service(
  Future<http.Response> Function(http.Request) handler, {
  String key = 'test-key',
}) => OpenAiService(
  client: MockClient(handler),
  apiKey: key,
  retryDelay: Duration.zero,
);

Map<String, dynamic> _body(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

Map<String, dynamic> _userJson(http.Request r) {
  final messages = _body(r)['messages'] as List<dynamic>;
  return jsonDecode(messages.last['content'] as String) as Map<String, dynamic>;
}

const _candidates = [
  DomFormField(
    elementId: 'a',
    tag: 'input',
    type: 'text',
    resolvedLabel: 'Từ khóa',
    labelSource: 'label_for',
  ),
  DomFormField(
    elementId: 'b',
    tag: 'input',
    type: 'text',
    resolvedLabel: 'Vị trí',
    labelSource: 'label_for',
  ),
];

void main() {
  group('milestone36 — intent parsing', () {
    test('sends transcript, n-best and language; uses the text model', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({
          'intentType': 'read_listing',
          'targetDescription': null,
          'confidence': 0.92,
        });
      });

      final result = await service.parseIntent(
        transcript: 'read this job listing',
        alternatives: ['read this job lasting'],
        languagePref: 'en',
      );

      expect(result.intentType, 'read_listing');
      expect(_body(seen)['model'], 'gpt-4o-mini');
      expect(_body(seen)['response_format'], {'type': 'json_object'});
      expect(seen.headers['Authorization'], 'Bearer test-key');
      expect(_userJson(seen), {
        'transcript': 'read this job listing',
        'nBestAlternatives': ['read this job lasting'],
        'languagePref': 'en',
      });
    });

    test('four clear utterances resolve, the ambiguous one does not', () async {
      final scripted = {
        'read this job listing': {
          'intentType': 'read_listing',
          'confidence': 0.95,
        },
        'apply to this job': {
          'intentType': 'fill_and_submit',
          'confidence': 0.9,
        },
        'đọc tin tuyển dụng này': {
          'intentType': 'read_listing',
          'confidence': 0.93,
        },
        'đưa tôi tới thanh tìm kiếm': {
          'intentType': 'navigate_to_element',
          'targetDescription': 'thanh tìm kiếm',
          'confidence': 0.88,
        },
        'uh the thing maybe': {
          'intentType': 'read_listing',
          'confidence': 0.3,
        },
      };
      final service = _service(
        (r) async => _reply(scripted[_userJson(r)['transcript']]!),
      );

      Future<IntentResult> parse(String t) =>
          service.parseIntent(transcript: t, languagePref: 'en');

      expect((await parse('read this job listing')).intentType, 'read_listing');
      expect((await parse('apply to this job')).intentType, 'fill_and_submit');
      expect(
        (await parse('đọc tin tuyển dụng này')).intentType,
        'read_listing',
      );
      final nav = await parse('đưa tôi tới thanh tìm kiếm');
      expect(nav.intentType, 'navigate_to_element');
      expect(nav.targetDescription, 'thanh tìm kiếm');

      final ambiguous = await parse('uh the thing maybe');
      expect(ambiguous.intentType, 'unrecognized');
      expect(ambiguous.isRecognized, isFalse);
    });

    test('confidence below 0.6 forces unrecognized', () async {
      final service = _service(
        (_) async =>
            _reply({'intentType': 'fill_and_submit', 'confidence': 0.59}),
      );
      final r = await service.parseIntent(transcript: 'x', languagePref: 'en');
      expect(r.intentType, 'unrecognized');
    });

    test('an unknown intent type is unrecognized', () async {
      final service = _service(
        (_) async => _reply({'intentType': 'order_pizza', 'confidence': 0.99}),
      );
      final r = await service.parseIntent(transcript: 'x', languagePref: 'en');
      expect(r.intentType, 'unrecognized');
    });
  });

  group('milestone37 — image to text', () {
    test('uses the vision model and sends the image as a data URI', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({
          'transcribedText': ' Senior Dev\nRequirements: Flutter ',
          'confidence': 0.9,
        });
      });

      final r = await service.imageToText(
        imageBase64: 'QUJD',
        mimeType: 'image/jpeg',
      );

      expect(r.text, 'Senior Dev\nRequirements: Flutter');
      expect(r.confidence, 0.9);
      expect(_body(seen)['model'], 'gpt-4o');
      final content = (_body(seen)['messages'] as List).last['content'] as List;
      expect(
        content[0]['text'],
        contains('job description posted as an image'),
      );
      expect(content[1]['image_url']['url'], 'data:image/jpeg;base64,QUJD');
    });
  });

  group('milestone38 — listing summarization', () {
    test('returns only the listing fields as a JobListing', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({
          'title': 'Flutter Developer',
          'company': 'Example Co',
          'requirements': '3 years Flutter',
          'howToApply': 'Fill in the form',
          'confidence': 0.85,
        });
      });

      final s = await service.summarizeListing(
        pageText: 'Accept cookies | Flutter Developer ... Related jobs ...',
        url: 'https://example.test/job/1',
      );

      expect(s.listing.title, 'Flutter Developer');
      expect(s.listing.company, 'Example Co');
      expect(s.listing.requirements, '3 years Flutter');
      expect(s.listing.howToApply, 'Fill in the form');
      expect(s.confidence, 0.85);
      expect(_userJson(seen)['url'], 'https://example.test/job/1');
    });

    test('the system prompt names concrete noise to ignore', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({'title': 't', 'confidence': 1});
      });
      await service.summarizeListing(pageText: 'x', url: 'u');
      final system =
          (_body(seen)['messages'] as List).first['content'] as String;
      for (final noise in [
        'cookie',
        'related jobs',
        'footer',
        'advertisements',
      ]) {
        expect(system.toLowerCase(), contains(noise));
      }
    });
  });

  group('milestone39 — element matching', () {
    test('a clear match is confident and sends the candidate list', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({
          'elementId': 'a',
          'confidence': 0.93,
          'reasoning': 'Labeled keywords.',
          'alternativeElementIds': <String>[],
        });
      });

      final m = await service.matchElement(
        targetDescription: 'search bar',
        candidates: _candidates,
      );

      expect(m.elementId, 'a');
      expect(m.isConfident(0.7), isTrue);
      final sent = _userJson(seen);
      expect(sent['targetDescription'], 'search bar');
      expect((sent['candidates'] as List).first['label'], 'Từ khóa');
      expect(seen.body, isNot(contains('<html')));
    });

    test('two ambiguous fields: below 0.7, both surfaced', () async {
      final service = _service(
        (_) async => _reply({
          'elementId': 'a',
          'confidence': 0.45,
          'reasoning': 'Both could be the search box.',
          'alternativeElementIds': ['b'],
        }),
      );
      final m = await service.matchElement(
        targetDescription: 'search box',
        candidates: _candidates,
      );
      expect(m.confidence, lessThan(0.7));
      expect(m.isConfident(0.7), isFalse);
      expect(m.alternativeElementIds, ['b']);
    });

    test('null elementId is a valid answer and never confident', () async {
      final service = _service(
        (_) async =>
            _reply({'elementId': null, 'confidence': 0.9, 'reasoning': 'none'}),
      );
      final m = await service.matchElement(
        targetDescription: 'fax number',
        candidates: _candidates,
      );
      expect(m.elementId, isNull);
      expect(m.isConfident(0.7), isFalse);
    });

    test('an id that is not a real candidate is discarded', () async {
      final service = _service(
        (_) async => _reply({
          'elementId': 'made-up',
          'confidence': 0.99,
          'reasoning': 'x',
          'alternativeElementIds': ['b', 'ghost'],
        }),
      );
      final m = await service.matchElement(
        targetDescription: 'search',
        candidates: _candidates,
      );
      expect(m.elementId, isNull);
      expect(m.confidence, 0.0);
      expect(m.alternativeElementIds, ['b']);
    });
  });

  group('milestone40 — PDF structuring', () {
    test('parses sections and inferred fields; sends detected fields', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({
          'sections': [
            {'heading': 'Personal details', 'body': 'Full name, email'},
            {'heading': 'Attachments', 'body': 'Attach CV'},
          ],
          'inferredFields': [
            {'label': 'Full name', 'inferredType': 'text'},
            {'label': 'CV', 'inferredType': 'file'},
          ],
        });
      });

      final s = await service.structurePdf(
        rawPdfText: 'Full name: ____',
        detectedFormFields: const [
          PdfFormField(name: 'fullName', type: 'text'),
        ],
      );

      expect(s.sections.map((e) => e.heading), [
        'Personal details',
        'Attachments',
      ]);
      expect(s.inferredFields.last.inferredType, 'file');
      expect(_userJson(seen)['detectedFormFields'], [
        {'name': 'fullName', 'type': 'text', 'value': null},
      ]);
    });

    test('very long PDF text is truncated before sending', () async {
      late http.Request seen;
      final service = _service((r) async {
        seen = r;
        return _reply({'sections': [], 'inferredFields': []});
      });
      await service.structurePdf(rawPdfText: 'x' * 50000);
      expect((_userJson(seen)['rawPdfText'] as String).length, 12000);
    });
  });

  group('transport behaviour', () {
    test('retries a 429 and then succeeds', () async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        if (calls == 1) return http.Response('slow down', 429);
        return _reply({'intentType': 'read_listing', 'confidence': 0.9});
      });
      final r = await service.parseIntent(transcript: 'x', languagePref: 'en');
      expect(calls, 2);
      expect(r.intentType, 'read_listing');
    });

    test('gives up after repeated 5xx', () async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        return http.Response('boom', 503);
      });
      await expectLater(
        service.parseIntent(transcript: 'x', languagePref: 'en'),
        throwsA(isA<OpenAiException>()),
      );
      expect(calls, 3);
    });

    test('a 401 is not retried', () async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        return http.Response('bad key', 401);
      });
      await expectLater(
        service.parseIntent(transcript: 'x', languagePref: 'en'),
        throwsA(
          isA<OpenAiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(calls, 1);
    });

    test('a non-JSON reply becomes an OpenAiException', () async {
      final service = _service(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'sorry, no'},
              },
            ],
          }),
          200,
        ),
      );
      await expectLater(
        service.parseIntent(transcript: 'x', languagePref: 'en'),
        throwsA(isA<OpenAiException>()),
      );
    });

    test('no key: isConfigured is false and calls fail without HTTP', () async {
      var calls = 0;
      final service = _service((_) async {
        calls++;
        return _reply({});
      }, key: '');
      expect(service.isConfigured, isFalse);
      await expectLater(
        service.parseIntent(transcript: 'x', languagePref: 'en'),
        throwsA(isA<OpenAiException>()),
      );
      expect(calls, 0);
    });
  });
}
