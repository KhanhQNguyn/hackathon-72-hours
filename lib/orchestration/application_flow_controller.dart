import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/constants.dart';
import '../core/language.dart';
import '../core/narration_lookup.dart';
import '../core/voice_replies.dart';
import '../models/dom_snapshot.dart';
import '../models/element_match_result.dart';
import '../models/openai_results.dart';
import '../models/pdf_form_field.dart';
import '../services/applicant_profile_service.dart';
import '../services/file_picker_service.dart';
import '../services/fuzzy_match_service.dart';
import '../services/openai_service.dart';
import '../services/page_load_exception.dart';
import '../services/pdf_parse_exception.dart';
import '../services/pdf_reader_service.dart';
import '../services/preferences_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/webview_controller_service.dart';
import '../utils/logger.dart';
import 'application_flow_fsm.dart';
import 'captcha_checkpoint_handler.dart';
import 'submit_hook.dart';
import 'voice_command_gate.dart';

enum _Outcome { confirmed, skipped, aborted }

/// An image downloaded for the vision call.
class FetchedImage {
  final Uint8List bytes;
  final String mimeType;

  const FetchedImage(this.bytes, this.mimeType);
}

/// Downloads [url] for image-to-text, or returns `null` if it can't be
/// fetched. Handles `data:` URIs; refuses anything over 4 MB.
Future<FetchedImage?> defaultImageFetcher(String url) async {
  try {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final header = url.substring(5, comma);
      if (!header.contains(';base64')) return null;
      return FetchedImage(
        base64Decode(url.substring(comma + 1)),
        header.split(';').first,
      );
    }
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.length > 4000000) {
      return null;
    }
    final type = response.headers['content-type']?.split(';').first;
    return FetchedImage(response.bodyBytes, type ?? 'image/png');
  } catch (e) {
    Logger.log('flow: could not fetch image: $e');
    return null;
  }
}

/// Drives one complete run of the flow — the "orchestrating caller" the
/// FSM's own comments refer to. It sequences the services and fires FSM
/// events; the FSM stays the single source of truth for *where* the flow
/// is, and the only place the real submit action can fire.
///
/// ```
/// trigger -> spoken command -> intent -> load page -> read listing
/// (+ image transcription, CAPTCHA check) -> confirm listing (checkpoint
/// 1) -> read form PDF -> per-field confirm loop -> final review (edit
/// loop) -> confirm (checkpoint 2) -> submit -> done
/// ```
///
/// Every spoken line is also published in [lastNarration] so the on-screen
/// status text mirrors the audio (WCAG 3.3.1, spec.md §7).
///
/// AI is optional: with no [openAi] (or no API key) each step falls back
/// to a plain behaviour — any accepted command means "apply", the visible
/// text is read as-is, images are only counted, the PDF text is read
/// verbatim — so the app stays usable, and testable, without a key.
class ApplicationFlowController extends ChangeNotifier {
  ApplicationFlowController({
    required this.fsm,
    required SpeechService speech,
    required this.tts,
    required this.preferences,
    required this.webView,
    required this.pdfReader,
    required this.profileService,
    required this.filePicker,
    this.captchaHandler,
    this.openAi,
    FuzzyMatchService? fuzzy,
    this.imageFetcher = defaultImageFetcher,
    this.formPdfPathProvider,
    this.askUserToChooseFormPdf = false,
    SubmitHook? submitHook,
  }) : _fuzzy = fuzzy ?? FuzzyMatchService() {
    _gate = VoiceCommandGate(
      fsm: fsm,
      speech: speech,
      tts: tts,
      preferences: preferences,
      narrate: narrate,
    );
    submitHook?.action = submitApplication;
  }

  final ApplicationFlowFsm fsm;
  final TtsService tts;
  final PreferencesService preferences;
  final WebViewControllerService webView;
  final PdfReaderService pdfReader;
  final ApplicantProfileService profileService;
  final FilePickerService filePicker;
  final CaptchaCheckpointHandler? captchaHandler;
  final OpenAiService? openAi;
  final Future<FetchedImage?> Function(String url) imageFetcher;

  /// Where the application-form PDF comes from; `null` skips the PDF step.
  /// Defaults to `AppConfig.applicationFormPdfPath`.
  final Future<String?> Function()? formPdfPathProvider;

  /// True on a real run, where the user has to pick the PDF themselves.
  final bool askUserToChooseFormPdf;

  final FuzzyMatchService _fuzzy;
  late final VoiceCommandGate _gate;
  bool _running = false;
  Map<String, String> _profile = {};
  final Map<String, String> _values = {};
  List<DomFormField> _fields = [];
  FlowNarration _n = FlowNarration(AppLanguage.en);

  /// `'en'` / `'vi'`, refreshed at the start of a run and by
  /// [refreshLanguage] when the settings screen changes it.
  String language = AppLanguage.en;

  /// Text of the most recent spoken line ('' before the first one).
  String lastNarration = '';

  bool get isRunning => _running;

  OpenAiService? get _ai {
    final ai = openAi;
    return ai != null && ai.isConfigured ? ai : null;
  }

  Future<void> refreshLanguage() async {
    language = await preferences.getLanguagePref();
    _n = FlowNarration(language);
    notifyListeners();
  }

  /// Speaks [text] and mirrors it on screen. A TTS failure is logged, not
  /// fatal: the text is still visible and announced by the live region.
  Future<void> narrate(String text) async {
    lastNarration = text;
    notifyListeners();
    try {
      await tts.speak(text);
    } catch (e) {
      Logger.log('flow: tts failed: $e');
    }
  }

  /// Starts a run. Safe to call from `Idle`, `Done` or `Error` (the last
  /// two are reset first); ignored while a run is in progress.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    try {
      if (fsm.state is! IdleState) await fsm.transition(const FlowReset());
      lastNarration = '';
      _values.clear();
      notifyListeners();
      await _run();
    } catch (e, st) {
      Logger.log('flow: unexpected failure: $e\n$st');
      await _fail(e.toString());
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _run() async {
    await refreshLanguage();

    final intent = await _listenForIntent();
    if (intent == null) return;
    if (intent.intentType == IntentType.navigateToElement) {
      // Feature 2 (Guided TalkBack Assist) is unconfirmed pending spike
      // A1b, so a "take me to X" request is acknowledged, not acted on.
      await narrate(_n.navigateUnsupported);
      await fsm.transition(const FlowReset());
      return;
    }
    await fsm.transition(const IntentParsed());

    await narrate(_n.loadingPage);
    if (!await _loadTarget()) return;
    await fsm.transition(const TargetLoaded());

    await narrate(_n.readingPage);
    var dom = await webView.readDom();
    switch (await _handleCaptcha()) {
      case _Outcome.aborted:
        return;
      case _Outcome.confirmed:
        dom = await webView.readDom();
      case _Outcome.skipped:
        break;
    }
    await fsm.transition(const ContentRead());

    await _narrateListing(dom);

    // Checkpoint 1: the user confirms this is the right listing.
    await narrate(_n.confirmListing);
    final listingReply = await _gate.listenConfident();
    if (listingReply == null) return _fail('No response to the listing question.');
    if (!isAffirmative(listingReply)) {
      await narrate(_n.listingDeclined);
      await fsm.transition(const FlowReset());
      return;
    }

    if (!await _readForm()) return;

    _fields = dom.labeledFields;
    _profile = await _loadProfile();
    await fsm.transition(
      ListingConfirmed(
        _fields.map((f) => f.elementId).toList(),
        fieldTypes: {
          for (final f in _fields)
            if (f.type != null) f.elementId: f.type!,
        },
      ),
    );

    // Per-field confirm loop.
    while (fsm.state is FillingFormState) {
      final state = fsm.state as FillingFormState;
      final field = _fieldById(state.currentFieldId);
      if (field == null) {
        await narrate(_n.fieldNotFound(state.currentFieldId));
        await fsm.transition(FieldSkippedNotFound(state.currentFieldId));
        continue;
      }
      switch (await _fillOne(field, offerSaved: true)) {
        case _Outcome.confirmed || _Outcome.skipped:
          await fsm.transition(FieldConfirmed(field.elementId));
        case _Outcome.aborted:
          return;
      }
    }

    // Final review, with the edit loop-back and checkpoint 2.
    while (fsm.state is FinalReviewState) {
      await narrate(_n.finalReview(_summary()));
      final reply = await _gate.listenConfident();
      if (reply == null) return _fail('No response at the final review.');

      // Edit is checked before "yes" so "correct my phone" is an edit,
      // not a confirmation.
      final target = editTarget(reply);
      if (target != null) {
        final field = await _resolveField(target);
        if (field == null) {
          await narrate(_n.noSuchField(target));
          continue;
        }
        await fsm.transition(EditFieldRequested(field.elementId));
        switch (await _fillOne(field, offerSaved: false)) {
          case _Outcome.confirmed || _Outcome.skipped:
            await fsm.transition(const FieldEditConfirmed());
          case _Outcome.aborted:
            return;
        }
      } else if (isAffirmative(reply)) {
        if (await _handleCaptcha() == _Outcome.aborted) return;
        await narrate(_n.submitting);
        await fsm.transition(const SubmitConfirmed());
        break;
      } else {
        await narrate(_n.didNotUnderstand);
      }
    }

    if (fsm.state is DoneState) {
      await narrate(_n.done);
    } else {
      await _reportError();
    }
  }

  // --- intent (milestone 36) ----------------------------------------------

  /// Listens for a command and classifies it. An unrecognised command
  /// re-prompts exactly like a low STT confidence (up to 3 tries).
  /// Returns `null` after ending the run in an error.
  Future<IntentResult?> _listenForIntent() async {
    const maxTries = 3;
    for (var attempt = 0; attempt < maxTries; attempt++) {
      await fsm.transition(const TriggerPressed());
      if (attempt == 0) await narrate(_n.commandPrompt);
      await _gate.run();
      if (fsm.state is! ParsingIntentState) {
        await _reportError();
        return null;
      }

      final intent = await _parseIntent();
      if (intent == null) return null;
      if (intent.isRecognized) return intent;

      await narrate(repromptMessage(language));
      await fsm.transition(const FlowReset());
    }
    await _fail("Couldn't understand the request.");
    return null;
  }

  Future<IntentResult?> _parseIntent() async {
    final ai = _ai;
    if (ai == null) {
      // No key: any accepted command means "read this listing and apply".
      return const IntentResult(
        intentType: IntentType.fillAndSubmit,
        confidence: 1.0,
      );
    }

    final accepted = _gate.lastAccepted;
    IntentResult? result;
    Future<bool> attempt() async {
      try {
        result = await ai.parseIntent(
          transcript: accepted?.transcript ?? '',
          alternatives: accepted?.alternatives ?? const [],
          languagePref: language,
        );
        return true;
      } on OpenAiException catch (e) {
        Logger.log('flow: intent parsing failed: $e');
        return false;
      }
    }

    if (await attempt()) return result;
    final before = fsm.state;
    await fsm.transition(
      ErrorOccurred("Couldn't reach the AI service.", retryAction: attempt),
    );
    if (fsm.state != before) {
      await _reportError();
      return null;
    }
    return result;
  }

  // --- page + listing (milestones 22, 37, 38) -------------------------------

  Future<bool> _loadTarget() async {
    Future<bool> attempt() async {
      try {
        await webView.loadTarget(AppConfig.targetUrl);
        return true;
      } on PageLoadException catch (e) {
        Logger.log('flow: page load failed: ${e.message}');
        return false;
      }
    }

    if (await attempt()) return true;
    await narrate(_n.pageRetrying);
    final before = fsm.state;
    await fsm.transition(
      ErrorOccurred('The page did not load.', retryAction: attempt),
    );
    if (fsm.state == before) return true;
    await _reportError();
    return false;
  }

  Future<void> _narrateListing(DomSnapshot dom) async {
    await _describeImages(dom);

    final ai = _ai;
    if (ai != null && dom.visibleText.trim().isNotEmpty) {
      try {
        final summary = await ai.summarizeListing(
          pageText: dom.visibleText,
          url: AppConfig.targetUrl,
        );
        if (summary.confidence >= 0.5 && summary.listing.title.isNotEmpty) {
          await narrate(_n.listingFromAi(summary.listing));
          return;
        }
      } on OpenAiException catch (e) {
        Logger.log('flow: listing summary failed, reading raw text: $e');
      }
    }
    await narrate(
      _n.listingSummary(
        text: _clip(dom.visibleText, 400),
        imagesWithoutAlt: dom.images.where((i) => !i.hasAlt).length,
      ),
    );
  }

  /// Transcribes images that carry no alt text — the core Stage 2 barrier
  /// (job descriptions posted as pictures). At most 3 per page, and only
  /// when AI is available (vision calls are the costly ones).
  Future<void> _describeImages(DomSnapshot dom) async {
    final ai = _ai;
    if (ai == null) return;
    for (final image in dom.images.where((i) => !i.hasAlt).take(3)) {
      final fetched = await imageFetcher(image.src);
      if (fetched == null) continue;
      try {
        final result = await ai.imageToText(
          imageBase64: base64Encode(fetched.bytes),
          mimeType: fetched.mimeType,
        );
        if (result.text.isNotEmpty && result.confidence >= 0.5) {
          await narrate(_n.imageTranscript(result.text));
        }
      } on OpenAiException catch (e) {
        Logger.log('flow: image transcription failed: $e');
      }
    }
  }

  // --- the application-form PDF (milestones 18-23, 40) -------------------------

  /// Reads the form aloud. Returns `false` if the run ended in an error.
  Future<bool> _readForm() async {
    if (askUserToChooseFormPdf) await narrate(_n.chooseFormPdf);
    final path = await (formPdfPathProvider ??
        () async => AppConfig.applicationFormPdfPath)();
    if (path == null) {
      await narrate(_n.noFormPdf);
      return true;
    }

    await narrate(_n.readingForm);
    try {
      final text = await pdfReader.extractTextWithOcrFallback(path);
      var detected = const <PdfFormField>[];
      try {
        detected = await pdfReader.extractFormFields(path);
      } catch (e) {
        Logger.log('flow: no AcroForm fields: $e');
      }

      final structure = await _structurePdf(text, detected);
      if (structure != null && structure.sections.isNotEmpty) {
        for (final s in structure.sections.take(8)) {
          await narrate(_n.formSection(s.heading, _clip(s.body, 300)));
        }
      } else {
        await narrate(_n.formText(_clip(text, 400)));
      }
      return true;
    } on PdfParseException catch (e) {
      await narrate(_n.pdfFailed);
      await _fail(e.message);
      return false;
    }
  }

  Future<PdfStructure?> _structurePdf(
    String text,
    List<PdfFormField> detected,
  ) async {
    final ai = _ai;
    if (ai == null) return null;
    try {
      return await ai.structurePdf(rawPdfText: text, detectedFormFields: detected);
    } on OpenAiException catch (e) {
      Logger.log('flow: PDF structuring failed, reading raw text: $e');
      return null;
    }
  }

  // --- CAPTCHA (checkpoint 3) ------------------------------------------------

  /// Checks for a CAPTCHA. `skipped` = none found, `confirmed` = handled
  /// (audio challenge, or the user solved it and said "continue"),
  /// `aborted` = the user never resumed.
  Future<_Outcome> _handleCaptcha() async {
    final handler = captchaHandler;
    if (handler == null) return _Outcome.skipped;
    if (!await handler.checkAndHandle(fsm)) return _Outcome.skipped;
    if (fsm.state is! CaptchaPendingState) return _Outcome.confirmed;

    lastNarration = await handler.handOffText();
    notifyListeners();
    for (var i = 0; i < 5; i++) {
      final reply = await _gate.listenConfident();
      if (reply == null) break;
      if (isContinue(reply)) {
        await fsm.transition(const CaptchaResolved());
        return _Outcome.confirmed;
      }
    }
    await _fail('The CAPTCHA was not resolved.');
    return _Outcome.aborted;
  }

  // --- the per-field loop -----------------------------------------------------

  /// Collects, fills and confirms one field.
  Future<_Outcome> _fillOne(
    DomFormField field, {
    required bool offerSaved,
  }) async {
    final label = _labelOf(field);
    final key = _profileKey(field);

    if (field.type == 'file') return _attachCv(field);

    final value = await _collectValue(
      label,
      offerSaved && key != null ? _profile[key] : null,
    );
    if (value == null) {
      await _fail('No answer was given for $label.');
      return _Outcome.aborted;
    }

    Future<bool> attempt() async =>
        (await webView.fillField(field.elementId, value)).success;

    await narrate(_n.fillingField(label));
    if (!await attempt()) {
      await narrate(_n.fillFailed(label));
      final before = fsm.state;
      await fsm.transition(
        ErrorOccurred("Couldn't fill in $label.", retryAction: attempt),
      );
      if (fsm.state != before) {
        await _reportError();
        return _Outcome.aborted;
      }
    }
    _values[field.elementId] = value;
    return _Outcome.confirmed;
  }

  Future<_Outcome> _attachCv(DomFormField field) async {
    final path = _profile['cvFilePath'] ?? await filePicker.pickCvFile();
    if (path == null) {
      await narrate(_n.cvNone);
      _values[field.elementId] = '-';
      return _Outcome.skipped;
    }
    await narrate(_n.cvChosen(path.split(RegExp(r'[\\/]')).last));
    await webView.triggerFileChooser(field.elementId);
    _values[field.elementId] = path;
    return _Outcome.confirmed;
  }

  /// Offers the saved value if there is one, otherwise asks; a spoken
  /// value is read back and must be confirmed. Returns `null` if the user
  /// never answers.
  Future<String?> _collectValue(String label, String? saved) async {
    if (saved != null && saved.isNotEmpty) {
      await narrate(_n.offerSaved(label, saved));
      final reply = await _gate.listenConfident();
      if (reply == null) return null;
      if (isAffirmative(reply)) return saved;
      if (!isNegative(reply)) {
        if (await _confirmSpoken(label, reply)) return reply;
      }
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      await narrate(_n.askValue(label));
      final reply = await _gate.listenConfident();
      if (reply == null) return null;
      if (await _confirmSpoken(label, reply)) return reply;
    }
    return null;
  }

  Future<bool> _confirmSpoken(String label, String value) async {
    await narrate(_n.confirmValue(label, value));
    final reply = await _gate.listenConfident();
    return reply != null && isAffirmative(reply);
  }

  Future<Map<String, String>> _loadProfile() async {
    try {
      return await profileService.getProfile() ?? {};
    } catch (e) {
      Logger.log('flow: could not load applicant profile: $e');
      return {};
    }
  }

  // --- matching a spoken field name to a field (milestones 39, 41) ----------------

  DomFormField? _fieldById(String id) {
    for (final f in _fields) {
      if (f.elementId == id) return f;
    }
    return null;
  }

  static String _labelOf(DomFormField f) =>
      f.resolvedLabel ?? f.ariaLabel ?? f.placeholder ?? f.name ?? f.elementId;

  /// Which saved-profile entry a field corresponds to, if any.
  static String? _profileKey(DomFormField f) {
    final text =
        '${_labelOf(f)} ${f.name ?? ''} ${f.type ?? ''}'.toLowerCase();
    if (f.type == 'file' || text.contains('cv') || text.contains('resume')) {
      return 'cvFilePath';
    }
    if (f.type == 'email' || text.contains('email') || text.contains('mail')) {
      return 'email';
    }
    if (f.type == 'tel' || text.contains('phone') || text.contains('điện thoại')) {
      return 'phone';
    }
    if (text.contains('name') || text.contains('tên')) return 'name';
    return null;
  }

  static const Map<String, String> _keySynonyms = {
    'name': 'name tên họ',
    'phone': 'phone số điện thoại',
    'email': 'email mail thư',
    'cvFilePath': 'cv file resume tệp',
  };

  /// Cheapest first: string similarity, then keyword synonyms, and only
  /// then the AI. A confident AI match is used directly; otherwise the
  /// user is asked which candidate they meant (spec.md §6) — the app
  /// never silently acts on a shaky guess.
  Future<DomFormField?> _resolveField(String target) async {
    final labels = _fields.map(_labelOf).toList();
    final fuzzyLabel = _fuzzy.bestMatch(target, labels);
    if (fuzzyLabel != null) return _fields[labels.indexOf(fuzzyLabel)];

    final keyword = _keywordMatch(target);
    if (keyword != null) return keyword;

    final ai = _ai;
    if (ai == null || _fields.isEmpty) return null;
    final ElementMatchResult match;
    try {
      match = await ai.matchElement(targetDescription: target, candidates: _fields);
    } on OpenAiException catch (e) {
      Logger.log('flow: element matching failed: $e');
      return null;
    }
    if (match.isConfident(AppConstants.elementMatchConfidenceThreshold)) {
      return _fieldById(match.elementId!);
    }

    final options = <DomFormField>[
      for (final id in [
        if (match.elementId != null) match.elementId!,
        ...match.alternativeElementIds,
      ])
        ?_fieldById(id),
    ];
    if (options.isEmpty) return null;

    final optionLabels = options.map(_labelOf).toList();
    await narrate(_n.disambiguate(optionLabels));
    final reply = await _gate.listenConfident();
    if (reply == null) return null;
    final chosen = _fuzzy.bestMatch(reply, optionLabels);
    if (chosen != null) return options[optionLabels.indexOf(chosen)];
    for (final f in options) {
      if (sharedWordCount(reply, _labelOf(f)) > 0) return f;
    }
    return null;
  }

  DomFormField? _keywordMatch(String target) {
    DomFormField? best;
    var bestScore = 0;
    for (final f in _fields) {
      final key = _profileKey(f);
      final score =
          sharedWordCount(target, _labelOf(f)) * 2 +
          (key == null ? 0 : sharedWordCount(target, _keySynonyms[key]!));
      if (score > bestScore) {
        best = f;
        bestScore = score;
      }
    }
    return best;
  }

  String _summary() => _fields
      .where((f) => _values.containsKey(f.elementId))
      .map((f) => '${_labelOf(f)}: ${_values[f.elementId]}')
      .join('. ');

  // --- the real submit (milestone 44) ---------------------------------------------

  /// The one real, side-effecting action: clicks the page's submit button.
  /// Wired in as the FSM's `performRealSubmit`, so it only ever runs from
  /// `SubmitConfirmed` in `FinalReviewState`. Throws (the FSM then enters
  /// `ErrorState`) rather than click something it isn't sure about.
  Future<void> submitApplication() async {
    final dom = await webView.readDom(); // fresh node ids
    final candidates = dom.submitCandidates;
    if (candidates.isEmpty) {
      throw StateError('No submit button was found on the page.');
    }

    var pick = candidates.first;
    if (candidates.length > 1) {
      final second = candidates[1];
      final clearlyFirst =
          (pick.heuristicScore ?? 0) > (second.heuristicScore ?? 0);
      final ai = _ai;
      if (ai != null) {
        final match = await ai.matchElement(
          targetDescription: 'button that submits the job application',
          candidates: candidates,
        );
        if (match.isConfident(AppConstants.elementMatchConfidenceThreshold)) {
          pick = candidates.firstWhere((c) => c.elementId == match.elementId);
        } else if (!clearlyFirst) {
          throw StateError('Not sure which button submits the application.');
        }
      } else if (!clearlyFirst) {
        throw StateError('Not sure which button submits the application.');
      }
    }

    if (!await webView.clickElement(pick.elementId)) {
      throw StateError('The submit button could not be clicked.');
    }
  }

  // --- helpers ---------------------------------------------------------------------

  static String _clip(String text, int max) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}...';
  }

  Future<void> _reportError() async {
    final state = fsm.state;
    if (state is ErrorState) await narrate(_n.failure(state.message));
  }

  Future<void> _fail(String message) async {
    if (fsm.state is! ErrorState) {
      await fsm.transition(ErrorOccurred(message));
    }
    await _reportError();
  }
}
