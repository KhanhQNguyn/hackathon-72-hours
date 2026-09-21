import 'dart:async';
import 'dart:convert';

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

/// A failed OpenAI call (HTTP error, timeout, or a reply that isn't the
/// JSON shape the prompt asked for).
class OpenAiException implements Exception {
  final String message;
  final int? statusCode;

  const OpenAiException(this.message, {this.statusCode});

  @override
  String toString() => 'OpenAiException: $message';
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
  final Duration retryDelay;
  final Duration timeout;

  // Read once per call site from dotenv (milestone03); `isInitialized`
  // guards tests and any run where `main` never loaded the file.
  String get _apiKey =>
      _apiKeyOverride ??
      (dotenv.isInitialized ? dotenv.env['OPENAI_API_KEY'] ?? '' : '');

  /// False when no key is configured — callers fall back to non-AI
  /// behaviour instead of failing every step.
  bool get isConfigured => _apiKey.trim().isNotEmpty;

  /// Trivial connectivity check (milestone03 Definition of Done).
  Future<String> debugPing() async {
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
  }

  // --- (a) intent parsing — milestone36 -----------------------------------

  /// Classifies [transcript] (plus STT n-best [alternatives]) into an
  /// intent. A result below `AppConstants.intentConfidenceThreshold`, or
  /// with an unknown `intentType`, is returned as `unrecognized` so the
  /// caller re-prompts exactly as it does for a low STT confidence.
  Future<IntentResult> parseIntent({
    required String transcript,
    List<String> alternatives = const [],
    required String languagePref,
  }) async {
    final json = await _completeJson(
      model: _textModel,
      system: intentParsingSystemPrompt,
      user: intentParsingUserMessage(
        transcript: transcript,
        nBestAlternatives: alternatives,
        languagePref: languagePref,
      ),
    );
    final type = json['intentType'];
    final confidence = _confidence(json['confidence']);
    if (type is! String ||
        !IntentType.all.contains(type) ||
        confidence < AppConstants.intentConfidenceThreshold) {
      return IntentResult(
        intentType: IntentType.unrecognized,
        confidence: confidence,
      );
    }
    return IntentResult(
      intentType: type,
      targetDescription: json['targetDescription'] as String?,
      confidence: confidence,
    );
  }

  // --- (b) image-to-text — milestone37 ------------------------------------

  /// Transcribes an image with `gpt-4o` vision. Only call for images
  /// whose `DomImage.hasAlt` is false, never for every image (cost).
  Future<ImageTranscription> imageToText({
    required String imageBase64,
    String mimeType = 'image/png',
  }) async {
    final json = await _completeJson(
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
      text: ((json['transcribedText'] as String?) ?? '').trim(),
      confidence: _confidence(json['confidence']),
    );
  }

  // --- (c) DOM filtering / summarization — milestone38 --------------------

  /// Extracts the real listing from [pageText] (`DomSnapshot.visibleText`,
  /// already capped) with navigation, ads and banners suppressed.
  Future<ListingSummary> summarizeListing({
    required String pageText,
    required String url,
  }) async {
    final json = await _completeJson(
      model: _textModel,
      system: domSummarizationSystemPrompt,
      user: domSummarizationUserMessage(pageText: pageText, url: url),
    );
    return ListingSummary(
      listing: JobListing.fromJson(json),
      confidence: _confidence(json['confidence']),
    );
  }

  // --- (d) PDF-text structuring — milestone40 -----------------------------

  Future<PdfStructure> structurePdf({
    required String rawPdfText,
    List<PdfFormField> detectedFormFields = const [],
  }) async {
    final json = await _completeJson(
      model: _textModel,
      system: pdfStructuringSystemPrompt,
      user: pdfStructuringUserMessage(
        rawPdfText: rawPdfText,
        detectedFormFields: detectedFormFields,
      ),
    );
    return PdfStructure(
      sections: [
        for (final s in (json['sections'] as List<dynamic>? ?? const []))
          if (s is Map<String, dynamic>)
            PdfSection(
              heading: (s['heading'] as String?) ?? '',
              body: (s['body'] as String?) ?? '',
            ),
      ],
      inferredFields: [
        for (final f in (json['inferredFields'] as List<dynamic>? ?? const []))
          if (f is Map<String, dynamic>)
            InferredPdfField(
              label: (f['label'] as String?) ?? '',
              inferredType: (f['inferredType'] as String?) ?? 'unknown',
            ),
      ],
    );
  }

  // --- (e) element / field matching — milestone39 -------------------------

  /// Picks the candidate best matching [targetDescription]. [candidates]
  /// must be the heuristic-narrowed list, never raw DOM. The result's
  /// `elementId` and alternatives are restricted to real candidate ids,
  /// so a hallucinated id can never be acted on. The caller decides
  /// whether to act via `ElementMatchResult.isConfident`.
  Future<ElementMatchResult> matchElement({
    required String targetDescription,
    required List<DomFormField> candidates,
  }) async {
    final json = await _completeJson(
      model: _textModel,
      system: elementMatchingSystemPrompt,
      user: elementMatchingUserMessage(
        targetDescription: targetDescription,
        candidates: candidates,
      ),
    );
    final valid = {for (final c in candidates) c.elementId};
    final rawId = json['elementId'];
    final id = rawId is String && valid.contains(rawId) ? rawId : null;
    final alternatives = [
      for (final a in (json['alternativeElementIds'] as List<dynamic>? ?? const []))
        if (a is String && valid.contains(a) && a != id) a,
    ];
    return ElementMatchResult(
      elementId: id,
      // A pick the model made but that isn't a real candidate carries no
      // confidence.
      confidence: id == null && rawId != null ? 0.0 : _confidence(json['confidence']),
      reasoning: (json['reasoning'] as String?) ?? '',
      alternativeElementIds: alternatives,
    );
  }

  // --- plumbing ------------------------------------------------------------

  /// Runs a JSON-mode chat completion and returns the parsed object.
  Future<Map<String, dynamic>> _completeJson({
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
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('reply is not a JSON object');
      }
      return decoded;
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
        throw const OpenAiException('OpenAI request timed out');
      }

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
      // Simple backoff on rate limits / transient server errors, not a
      // queue (spec.md §3 "OpenAI rate limits").
      final retryable =
          response.statusCode == 429 || response.statusCode >= 500;
      if (retryable && attempt < _maxRetries) {
        Logger.log(
          'openai: ${response.statusCode}, retry ${attempt + 1}/$_maxRetries',
        );
        await Future<void>.delayed(retryDelay * (attempt + 1));
        continue;
      }
      throw OpenAiException(
        'OpenAI API call failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  static double _confidence(Object? value) =>
      value is num ? value.toDouble().clamp(0.0, 1.0) : 0.0;
}
