import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/services/openai_service.dart';

// Audit 1.3 — real models don't always answer with bare, well-typed JSON,
// and a venue network is not reliable. These pin the tolerance added to the
// service. They do not (cannot) prove what the live model returns.

http.Response _raw(String content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': content},
      },
    ],
  }),
  200,
);

OpenAiService _service(
  Future<http.Response> Function(http.Request) handler,
) => OpenAiService(
  client: MockClient(handler),
  apiKey: 'k',
  retryDelay: Duration.zero,
  maxRetryAfter: Duration.zero,
);

const _intentJson = '{"intentType":"read_listing","confidence":0.9}';

Future<String> _intent(OpenAiService s) async =>
    (await s.parseIntent(transcript: 'x', languagePref: 'en')).intentType;

void main() {
  group('parseModelJson', () {
    test('plain JSON', () {
      expect(parseModelJson(_intentJson)['confidence'], 0.9);
    });

    test('```json fenced', () {
      expect(parseModelJson('```json\n$_intentJson\n```')['intentType'], 'read_listing');
    });

    test('bare ``` fence and surrounding whitespace', () {
      expect(parseModelJson('  ```\n$_intentJson\n```  ')['intentType'], 'read_listing');
    });

    test('prose before and after the object', () {
      expect(
        parseModelJson('Sure! Here you go:\n$_intentJson\nHope that helps.')['intentType'],
        'read_listing',
      );
    });

    test('braces inside string values do not confuse the extractor', () {
      final m = parseModelJson('Result: {"reasoning":"a } b { c","confidence":0.5} done');
      expect(m['reasoning'], 'a } b { c');
    });

    test('no object at all throws FormatException', () {
      expect(() => parseModelJson('I cannot help with that.'), throwsFormatException);
    });

    test('a JSON array is not accepted', () {
      expect(() => parseModelJson('[1,2]'), throwsFormatException);
    });
  });

  group('service tolerance', () {
    test('a fenced reply is parsed through the whole call', () async {
      final s = _service((_) async => _raw('```json\n$_intentJson\n```'));
      expect(await _intent(s), 'read_listing');
    });

    test('differently cased / separated keys are found', () async {
      for (final body in [
        '{"IntentType":"read_listing","Confidence":0.9}',
        '{"intent_type":"read_listing","confidence":0.9}',
        '{"intent-type":"read_listing","CONFIDENCE":"0.9"}',
      ]) {
        expect(await _intent(_service((_) async => _raw(body))), 'read_listing', reason: body);
      }
    });

    test('an intent type in a different case is accepted', () async {
      final s = _service((_) async => _raw('{"intentType":"Read_Listing","confidence":0.9}'));
      expect(await _intent(s), 'read_listing');
    });

    test('wrong-typed fields degrade instead of throwing a TypeError', () async {
      final s = _service(
        (_) async => _raw('{"title":["a"],"company":{"x":1},"requirements":5,"confidence":"high"}'),
      );
      final r = await s.summarizeListing(pageText: 't', url: 'u');
      expect(r.listing.title, '');
      expect(r.listing.company, '');
      expect(r.listing.requirements, '5');
      expect(r.confidence, 0.0);
    });

    test('a null message content is an OpenAiException, not a crash', () async {
      final s = _service(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {'message': {'content': null}},
            ],
          }),
          200,
        ),
      );
      await expectLater(_intent(s), throwsA(isA<OpenAiException>()));
    });

    test('sections with odd shapes are skipped, not fatal', () async {
      final s = _service(
        (_) async => _raw('{"sections":["oops",{"heading":"A","body":"b"},7],"inferredFields":"none"}'),
      );
      final r = await s.structurePdf(rawPdfText: 'x');
      expect(r.sections.map((e) => e.heading), ['A']);
      expect(r.inferredFields, isEmpty);
    });

    test('a candidate id returned with different whitespace still validates', () async {
      final s = _service(
        (_) async => _raw('{"elementId":" a ","confidence":0.9,"reasoning":"ok"}'),
      );
      final m = await s.matchElement(
        targetDescription: 't',
        candidates: const [DomFormField(elementId: 'a', tag: 'input')],
      );
      expect(m.elementId, 'a');
    });
  });

  group('transport failures all surface as OpenAiException', () {
    test('SocketException (no network)', () async {
      final s = _service((_) async => throw const SocketException('offline'));
      await expectLater(_intent(s), throwsA(isA<OpenAiException>()));
    });

    test('http ClientException', () async {
      final s = _service((_) async => throw http.ClientException('reset'));
      await expectLater(_intent(s), throwsA(isA<OpenAiException>()));
    });

    test('a timeout is retried once, then succeeds', () async {
      var calls = 0;
      final s = OpenAiService(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) throw TimeoutException('slow');
          return _raw(_intentJson);
        }),
        apiKey: 'k',
        retryDelay: Duration.zero,
      );
      expect(await _intent(s), 'read_listing');
      expect(calls, 2);
    });

    test('two timeouts in a row give up', () async {
      var calls = 0;
      final s = OpenAiService(
        client: MockClient((_) async {
          calls++;
          throw TimeoutException('slow');
        }),
        apiKey: 'k',
        retryDelay: Duration.zero,
      );
      await expectLater(_intent(s), throwsA(isA<OpenAiException>()));
      expect(calls, 2);
    });

    test('a non-JSON HTTP 200 body is an OpenAiException', () async {
      final s = _service((_) async => http.Response('<html>proxy login</html>', 200));
      await expectLater(_intent(s), throwsA(isA<OpenAiException>()));
    });

    test('429 with Retry-After is retried and then succeeds', () async {
      var calls = 0;
      final s = _service((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('slow down', 429, headers: {'retry-after': '3'});
        }
        return _raw(_intentJson);
      });
      expect(await _intent(s), 'read_listing');
      expect(calls, 2);
    });

    test('a huge Retry-After is capped rather than honoured', () async {
      final stopwatch = Stopwatch()..start();
      var calls = 0;
      final s = _service((_) async {
        calls++;
        if (calls == 1) {
          return http.Response('slow', 429, headers: {'retry-after': '3600'});
        }
        return _raw(_intentJson);
      });
      await _intent(s);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
