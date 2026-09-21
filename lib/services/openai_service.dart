import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/dom_snapshot.dart';
import '../models/element_match_result.dart';
import '../models/job_listing.dart';
import '../models/openai_results.dart';
import '../models/pdf_form_field.dart';
import '../utils/logger.dart';
import 'prompts/dom_summarization_prompt.dart';
import 'prompts/element_matching_prompt.dart';
import 'prompts/image_to_text_prompt.dart';
import 'prompts/intent_parsing_prompt.dart';
import 'prompts/pdf_structuring_prompt.dart';

/// A failed OpenAI call: HTTP error, network failure, timeout, or a reply
/// that isn't the JSON shape the prompt asked for. Every failure of this
/// service surfaces as this type so callers can degrade to non-AI
/// behaviour with a single `on OpenAiException`.
class OpenAiException implements Exception {
  final String message;
  final int? statusCode;

  const OpenAiException(this.message, {this.statusCode});

  @override
  String toString() => 'OpenAiException: $message';
}

/// Extracts the JSON object from a model reply, tolerating the ways real
/// models wrap it: a ```json fence, or prose before/after the object.
/// Throws [FormatException] if no object can be found.
@visibleForTesting
Map<String, dynamic> parseModelJson(String content) {
  var text = content.trim();

  final fence = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
    caseSensitive: false,
  ).firstMatch(text);
  if (fence != null) text = fence.group(1)!.trim();

  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    final object = _firstBalancedObject(text);
    if (object == null) {
      throw const FormatException('no JSON object in the reply');
    }
    decoded = jsonDecode(object);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('reply is not a JSON object');
  }
  return decoded;
}

/// The first `{...}` in [text] with balanced braces, ignoring braces that
/// sit inside JSON strings.
String? _firstBalancedObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}

/// Read access to a model's JSON object that is tolerant of key casing and
/// separators (`intentType` / `intent_type` / `IntentType`) and of values
/// with the wrong type, so a slightly-off reply degrades instead of
/// throwing a `TypeError` far from the parse.
class _Fields {
  _Fields(Map<String, dynamic> json)
    : _byNormalizedKey = {
        for (final e in json.entries) _normalize(e.key): e.value,
      };

  final Map<String, Object?> _byNormalizedKey;

  static String _normalize(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

  Object? raw(String key) => _byNormalizedKey[_normalize(key)];

  /// A trimmed string; numbers and booleans are stringified; anything else
  /// (null, list, map) is `null`.
  String? str(String key) {
    final v = raw(key);
    if (v is String) return v.trim();
    if (v is num || v is bool) return v.toString();
    return null;
  }

  /// A number in [0, 1]; a numeric string is accepted; otherwise 0.
  double confidence(String key) {
    final v = raw(key);
    final n = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    return (n ?? 0.0).clamp(0.0, 1.0);
  }

  List<Object?> list(String key) {
    final v = raw(key);
    return v is List ? v : const [];
  }

  /// Objects in the list at [key], each wrapped for tolerant reads.
  List<_Fields> objects(String key) => [
    for (final item in list(key))
      if (item is Map) _Fields(item.cast<String, dynamic>()),
  ];
}

/// Wraps calls to the OpenAI API. See spec.md §1, §6 for the five call
/// types (plan.md C1): intent parsing, image-to-text, DOM summarization,
/// PDF structuring and element matching. Prompts take the page/PDF
/// content as generic parameters, never one portal's field names.
///
/// Every call sends only the minimal context needed (spec.md §2).
class OpenAiService {
  OpenAiService({
    http.Client? client,
    String? apiKey,
    this.retryDelay = const Duration(seconds: 1),
    this.maxRetryAfter = const Duration(seconds: 10),
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _apiKeyOverride = apiKey;

  static const String _chatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _textModel = 'gpt-4o-mini';
  static const String _visionModel = 'gpt-4o';
  static const int _maxRetries = 2;

  final http.Client _client;
  final String? _apiKeyOverride;

  /// Base backoff between retries of a 429/5xx (multiplied by the attempt).
  final Duration retryDelay;

  /// Upper bound on how long a `Retry-After` header can make us wait.
  final Duration maxRetryAfter;
  final Duration timeout;

  // Read per call from dotenv (milestone03); `isInitialized` guards tests
  // and any run where `main` never loaded the file.
  String get _apiKey =>
      _apiKeyOverride ??
      (dotenv.isInitialized ? dotenv.env['OPENAI_API_KEY'] ?? '' : '');

  /// False when no key is configured — callers fall back to non-AI
  /// behaviour instead of failing every step.
  bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Trivial connectivity check (milestone03 Definition of Done).
  Future<String> debugPing() => _guard(() async {
    final json = await _chat(
      model: _textModel,
      messages: [
        {'role': 'user', 'content': 'Say hello in one word.'},
      ],
      jsonMode: false,
    );
    final choices = json['choices'] as List<dynamic>;
    return (choices.first as Map<String, dynamic>)['message']['content']
        as String;
  });

  // --- (a) intent parsing — milestone36 -----------------------------------

  /// Classifies [transcript] (plus STT n-best [alternatives]) into an
  /// intent. A result below `AppConstants.intentConfidenceThreshold`, or
  /// with an unknown `intentType`, is returned as `unrecognized` so the
  /// caller re-prompts exactly as it does for a low STT confidence.
  Future<IntentResult> parseIntent({
    required String transcript,
    List<String> alternatives = const [],
    required String languagePref,
  }) => _guard(() async {
    final f = await _completeJson(
      model: _textModel,
      system: intentParsingSystemPrompt,
      user: intentParsingUserMessage(
        transcript: transcript,
        nBestAlternatives: alternatives,
        languagePref: languagePref,
      ),
    );
    final type = f.str('intentType')?.toLowerCase();
    final confidence = f.confidence('confidence');
    if (type == null ||
        !IntentType.all.contains(type) ||
        confidence < AppConstants.intentConfidenceThreshold) {
      return IntentResult(
        intentType: IntentType.unrecognized,
        confidence: confidence,
      );
    }
    final target = f.str('targetDescription');
    return IntentResult(
      intentType: type,
      targetDescription: target == null || target.isEmpty ? null : target,
      confidence: confidence,
    );
  });

  // --- (b) image-to-text — milestone37 ------------------------------------

  /// Transcribes an image with `gpt-4o` vision. Only call for images
  /// whose `DomImage.hasAlt` is false, never for every image (cost).
  Future<ImageTranscription> imageToText({
    required String imageBase64,
    String mimeType = 'image/png',
  }) => _guard(() async {
    final f = await _completeJson(
      model: _visionModel,
      system: imageToTextSystemPrompt,
      user: [
        {'type': 'text', 'text': imageToTextContextHint},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
        },
      ],
      timeout: const Duration(seconds: 60),
    );
    return ImageTranscription(
      text: f.str('transcribedText') ?? '',
      confidence: f.confidence('confidence'),
    );
  });

  // --- (c) DOM filtering / summarization — milestone38 --------------------

  /// Extracts the real listing from [pageText] (`DomSnapshot.visibleText`,
  /// already capped) with navigation, ads and banners suppressed.
  Future<ListingSummary> summarizeListing({
    required String pageText,
    required String url,
  }) => _guard(() async {
    final f = await _completeJson(
      model: _textModel,
      system: domSummarizationSystemPrompt,
      user: domSummarizationUserMessage(pageText: pageText, url: url),
    );
    return ListingSummary(
      listing: JobListing(
        title: f.str('title') ?? '',
        company: f.str('company') ?? '',
        requirements: f.str('requirements') ?? '',
        howToApply: f.str('howToApply') ?? '',
      ),
      confidence: f.confidence('confidence'),
    );
  });

  // --- (d) PDF-text structuring — milestone40 -----------------------------

  Future<PdfStructure> structurePdf({
    required String rawPdfText,
    List<PdfFormField> detectedFormFields = const [],
  }) => _guard(() async {
    final f = await _completeJson(
      model: _textModel,
      system: pdfStructuringSystemPrompt,
      user: pdfStructuringUserMessage(
        rawPdfText: rawPdfText,
        detectedFormFields: detectedFormFields,
      ),
    );
    return PdfStructure(
      sections: [
        for (final s in f.objects('sections'))
          PdfSection(
            heading: s.str('heading') ?? '',
            body: s.str('body') ?? '',
          ),
      ],
      inferredFields: [
        for (final field in f.objects('inferredFields'))
          InferredPdfField(
            label: field.str('label') ?? '',
            inferredType: field.str('inferredType') ?? 'unknown',
          ),
      ],
    );
  });

  // --- (e) element / field matching — milestone39 -------------------------

  /// Picks the candidate best matching [targetDescription]. [candidates]
  /// must be the heuristic-narrowed list, never raw DOM. The result's
  /// `elementId` and alternatives are restricted to real candidate ids,
  /// so a hallucinated id can never be acted on. The caller decides
  /// whether to act via `ElementMatchResult.isConfident`.
  Future<ElementMatchResult> matchElement({
    required String targetDescription,
    required List<DomFormField> candidates,
  }) => _guard(() async {
    final f = await _completeJson(
      model: _textModel,
      system: elementMatchingSystemPrompt,
      user: elementMatchingUserMessage(
        targetDescription: targetDescription,
        candidates: candidates,
      ),
    );
    final valid = {for (final c in candidates) c.elementId};
    final rawId = f.str('elementId');
    final id = rawId != null && valid.contains(rawId) ? rawId : null;
    final alternatives = [
      for (final a in f.list('alternativeElementIds'))
        if (a is String && valid.contains(a) && a != id) a,
    ];
    return ElementMatchResult(
      elementId: id,
      // A pick the model made that isn't a real candidate carries no
      // confidence.
      confidence: id == null && rawId != null && rawId.isNotEmpty
          ? 0.0
          : f.confidence('confidence'),
      reasoning: f.str('reasoning') ?? '',
      alternativeElementIds: alternatives,
    );
  });

  // --- plumbing ------------------------------------------------------------

  /// Guarantees every failure leaving this service is an
  /// [OpenAiException], whatever went wrong inside.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on OpenAiException {
      rethrow;
    } catch (e) {
      throw OpenAiException('Unexpected failure: $e');
    }
  }

  /// Runs a JSON-mode chat completion and returns tolerant field access to
  /// the parsed object.
  Future<_Fields> _completeJson({
    required String model,
    required String system,
    required Object user,
    Duration? timeout,
  }) async {
    final response = await _chat(
      model: model,
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      timeout: timeout,
    );
    try {
      final choices = response['choices'] as List<dynamic>;
      final content =
          (choices.first as Map<String, dynamic>)['message']['content']
              as String;
      return _Fields(parseModelJson(content));
    } on Object catch (e) {
      throw OpenAiException('Unexpected reply shape: $e');
    }
  }

  Future<Map<String, dynamic>> _chat({
    required String model,
    required List<Map<String, Object?>> messages,
    bool jsonMode = true,
    Duration? timeout,
  }) async {
    if (!isConfigured) {
      throw const OpenAiException(
        'OPENAI_API_KEY is not set in .env — see .env.example (milestone03).',
      );
    }
    final body = jsonEncode({
      'model': model,
      'temperature': 0,
      'messages': messages,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    });

    var timeoutRetried = false;
    for (var attempt = 0; ; attempt++) {
      final http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse(_chatCompletionsUrl),
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(timeout ?? this.timeout);
      } on TimeoutException {
        // One retry: a slow first byte is common on a congested venue
        // network, but don't stall a spoken flow for longer than that.
        if (!timeoutRetried) {
          timeoutRetried = true;
          Logger.log('openai: timed out, retrying once');
          continue;
        }
        throw const OpenAiException('OpenAI request timed out');
      } on SocketException catch (e) {
        throw OpenAiException('No network connection: ${e.message}');
      } on http.ClientException catch (e) {
        throw OpenAiException('Network error: ${e.message}');
      }

      if (response.statusCode == 200) {
        try {
          return jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
        } on Object catch (e) {
          throw OpenAiException('Unreadable OpenAI response: $e');
        }
      }

      // Simple backoff on rate limits / transient server errors, not a
      // queue (spec.md §3 "OpenAI rate limits").
      final retryable =
          response.statusCode == 429 || response.statusCode >= 500;
      if (retryable && attempt < _maxRetries) {
        final wait = _retryWait(response, attempt);
        Logger.log(
          'openai: ${response.statusCode}, retry ${attempt + 1}/$_maxRetries '
          'in ${wait.inMilliseconds}ms',
        );
        await Future<void>.delayed(wait);
        continue;
      }
      throw OpenAiException(
        'OpenAI API call failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  /// `Retry-After` (seconds), capped at [maxRetryAfter], else linear
  /// backoff.
  Duration _retryWait(http.Response response, int attempt) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    if (seconds != null && seconds >= 0) {
      final asked = Duration(seconds: seconds);
      return asked > maxRetryAfter ? maxRetryAfter : asked;
    }
    return retryDelay * (attempt + 1);
  }
}
