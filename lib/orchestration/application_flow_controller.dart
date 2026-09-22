import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
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

/// A failure whose message is already written for the user, in their
/// language. The FSM stores `toString()` in `ErrorState.message`, which is
/// then spoken — so it must never be a raw exception string.
class FlowFailure implements Exception {
  final String message;

  const FlowFailure(this.message);

  @override
  String toString() => message;
}

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

/// Waits for the system file chooser to come and go: the app pauses when
/// it opens and resumes when it closes. If the chooser never takes the
/// screen (no pause within 5 s) it returns rather than waiting for a
/// resume that will not come. Needs a device to exercise.
Future<void> defaultAwaitFileChooser() async {
  final done = Completer<void>();
  var sawPause = false;
  final listener = AppLifecycleListener(
    onInactive: () => sawPause = true,
    onPause: () => sawPause = true,
    onResume: () {
      if (sawPause && !done.isCompleted) done.complete();
    },
  );
  final noChooser = Timer(const Duration(seconds: 5), () {
    if (!sawPause && !done.isCompleted) done.complete();
  });
  final giveUp = Timer(const Duration(minutes: 3), () {
    if (!done.isCompleted) done.complete();
  });
  try {
    await done.future;
  } finally {
    listener.dispose();
    noChooser.cancel();
    giveUp.cancel();
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
///
/// After an error the user can say "retry" (audit 1.6): a failed submit
/// resumes at the final review; anything else starts a fresh run. At most
/// [maxVoiceRetries] per run.
class ApplicationFlowController extends ChangeNotifier {
  ApplicationFlowController({
    required this.fsm,
    required SpeechService speech,
    required this.tts,
    required this.preferences,
    required this.webView,
    required this.pdfReader,
    required this.profileService,
    this.captchaHandler,
    this.openAi,
    FuzzyMatchService? fuzzy,
    this.imageFetcher = defaultImageFetcher,
    this.formPdfPathProvider,
    this.askUserToChooseFormPdf = false,
    SubmitHook? submitHook,
    this.settleDelay = Duration.zero,
    this.settleMaxWait = const Duration(seconds: 8),
    this.awaitFileChooser = defaultAwaitFileChooser,
    this.maxVoiceRetries = 2,
  }) : _fuzzy = fuzzy ?? FuzzyMatchService() {
    _gate = VoiceCommandGate(
      fsm: fsm,
      speech: speech,
      tts: tts,
      preferences: preferences,
      narrate: narrate,
      onListeningChanged: _setListening,
      playCues: true,
    );
    // One attempt only: after an error the user is asked once whether to
    // retry, and silence simply means "no".
    _retryGate = VoiceCommandGate(
      fsm: fsm,
      speech: speech,
      tts: tts,
      preferences: preferences,
      maxAttempts: 1,
      narrate: narrate,
      onListeningChanged: _setListening,
      playCues: true,
    );
    submitHook?.action = submitApplication;
  }

  final ApplicationFlowFsm fsm;
  final TtsService tts;
  final PreferencesService preferences;
  final WebViewControllerService webView;
  final PdfReaderService pdfReader;
  final ApplicantProfileService profileService;
  final CaptchaCheckpointHandler? captchaHandler;
  final OpenAiService? openAi;
  final Future<FetchedImage?> Function(String url) imageFetcher;

  /// Where the application-form PDF comes from; `null` skips the PDF step.
  /// Defaults to `AppConfig.applicationFormPdfPath`.
  final Future<String?> Function()? formPdfPathProvider;

  /// True on a real run, where the user has to pick the PDF themselves.
  final bool askUserToChooseFormPdf;

  /// How long the page must be quiet (no DOM mutations) before it is read;
  /// zero disables the wait (mocked runs, tests). A single-page app is
  /// often half-rendered at `onLoadStop` (spec.md §5 perceive → act →
  /// wait-for-stable), and this is what stops the flow reading that.
  final Duration settleDelay;

  /// Upper bound on the settle wait.
  final Duration settleMaxWait;

  /// Completes when the system file chooser has closed (see
  /// [defaultAwaitFileChooser]).
  final Future<void> Function() awaitFileChooser;

  final int maxVoiceRetries;

  final FuzzyMatchService _fuzzy;
  late final VoiceCommandGate _gate;
  late final VoiceCommandGate _retryGate;
  bool _running = false;
  Map<String, String> _profile = {};
  final Map<String, String> _values = {};
  List<DomFormField> _fields = [];
  FlowNarration _n = FlowNarration(AppLanguage.en);

  /// One-shot: set at the start of the real-target search_job flow so
  /// [submitApplication] also polls for a real success signal (item F)
  /// before declaring done, instead of trusting the click alone as every
  /// other flow through this method still does. Reset after each use so
  /// it never leaks into an unrelated run.
  bool _requireSubmitSuccessSignal = false;

  /// `'en'` / `'vi'`, refreshed at the start of a run and by
  /// [refreshLanguage] when the settings screen changes it.
  String language = AppLanguage.en;

  /// Text of the most recent spoken line ('' before the first one).
  String lastNarration = '';

  bool _isListening = false;

  /// True exactly while the recognizer is open (fed by
  /// [VoiceCommandGate.onListeningChanged], the only place `listen()` is
  /// called). The mic button reads this, not the FSM state, because the
  /// mic is also open during in-flow confirmations while the FSM sits in
  /// `FillingForm`/`FinalReview`.
  bool get isListening => _isListening;

  void _setListening(bool value) {
    if (_isListening == value) return;
    _isListening = value;
    notifyListeners();
  }

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
      _requireSubmitSuccessSignal = false;
      notifyListeners();
      await _run();
      await _retryByVoice();
    } catch (e, st) {
      Logger.log('flow: unexpected failure: $e\n$st');
      await _fail(_n.errUnexpected);
    } finally {
      _setListening(false);
      _running = false;
      notifyListeners();
    }
  }

  /// Offers "say retry" after an error and acts on it (audit 1.6b).
  Future<void> _retryByVoice() async {
    var retries = 0;
    while (fsm.state is ErrorState && retries < maxVoiceRetries) {
      final error = fsm.state as ErrorState;
      if (!await _askToRetry()) return;
      retries++;
      if (error.failedState is FinalReviewState) {
        // Submit failed: everything is already filled, resume at the review.
        await fsm.transition(const RetryRequested());
        await _finalReviewAndSubmit();
      } else {
        await fsm.transition(const FlowReset());
        _values.clear();
        await _run();
      }
    }
  }

  Future<bool> _askToRetry() async {
    if (_gate.speechUnavailable) return false; // saying "retry" can't help
    await narrate(_n.retryPrompt);
    final reply = await _retryGate.listenConfident();
    return reply != null && isRetry(reply);
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
    if (intent.intentType == IntentType.searchJob) {
      await _runSearchJobFlow(intent.targetDescription ?? '');
      return;
    }
    await fsm.transition(const IntentParsed());

    await narrate(_n.loadingPage);
    if (!await _loadTarget()) return;
    await fsm.transition(const TargetLoaded());

    await narrate(_n.readingPage);
    await _waitForStable();
    var dom = await webView.readDom();
    switch (await _handleCaptcha()) {
      case _Outcome.aborted:
        return;
      case _Outcome.confirmed:
        await _waitForStable();
        dom = await webView.readDom();
      case _Outcome.skipped:
        break;
    }
    await fsm.transition(const ContentRead());

    await _narrateListing(dom);

    // Checkpoint 1: the user confirms this is the right listing.
    await narrate(_n.confirmListing);
    final listingReply = await _gate.listenConfident();
    if (listingReply == null) return _fail(_n.errNoListingReply);
    if (!isAffirmative(listingReply)) {
      await narrate(_n.listingDeclined);
      await fsm.transition(const FlowReset());
      return;
    }

    if (!await _readForm()) return;

    _fields = _formFields(dom);
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

    if (!await _runFieldLoop()) return;
    await _finalReviewAndSubmit();
  }

  /// The per-field confirm loop (spec.md §5): drains `FillingFormState`
  /// one field at a time. Shared by the linear flow above and the
  /// real-target search_job flow ([_runSearchJobFlow]) once the apply
  /// form's fields are known. Returns `false` if the run ended (in error)
  /// mid-loop, in which case the caller must not proceed further.
  Future<bool> _runFieldLoop() async {
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
          return false;
      }
    }
    return true;
  }

  // --- real-target demo flow: search VietnamWorks (search_job intent) -------
  //
  // Deliberately VietnamWorks-specific throughout (task brief: "do not
  // build this generically") — every heuristic it relies on
  // (dom_reader.js's locateSearchSubmitButton/getResultCards/
  // dismissApplyUpsell/detectApplySuccess) assumes vietnamworks.com's
  // real DOM shape, not a general site.
  //
  // Sequence: open homepage -> type+submit the real search (or, behind
  // AppConfig.liveSearchTyping=false, skip straight to a direct results
  // URL) -> read the real result cards aloud, matching the user's spoken
  // reply by word overlap -> click into the chosen job's detail page and
  // reuse the existing read_listing narration -> ask to apply -> click
  // the real "Nộp đơn" button (reusing the generic submitCandidates
  // heuristic, which already recognizes it) and dismiss the AI-upsell
  // modal VNW sometimes shows -> reuse the existing per-field loop and
  // final review/submit, with success verification switched on.

  Future<void> _runSearchJobFlow(String query) async {
    await fsm.transition(const IntentParsed());
    await narrate(_n.searchingFor(query));

    if (!await _openSearchResults(query)) return;
    await fsm.transition(const TargetLoaded());

    await _waitForStable();
    var dom = await webView.readDom();
    switch (await _handleCaptcha()) {
      case _Outcome.aborted:
        return;
      case _Outcome.confirmed:
        await _waitForStable();
        dom = await webView.readDom();
      case _Outcome.skipped:
        break;
    }

    final cards = await webView.getResultCards();
    Logger.log('results: found ${cards.length} job cards');
    if (cards.isEmpty) {
      await _fail(_n.noResultsFound);
      return;
    }

    await narrate(_n.resultsFound(cards.length));
    for (var i = 0; i < cards.length; i++) {
      final c = cards[i];
      await _locateAndAnnounce(
        c.elementId,
        _n.resultCardLabel(i + 1, c.title, c.company, c.location),
      );
    }

    await narrate(_n.whichResult);
    JobResultCard? chosen;
    for (var attempt = 0; attempt < 3 && chosen == null; attempt++) {
      final reply = await _gate.listenConfident();
      if (reply == null) {
        await _fail(_n.errNoListingReply);
        return;
      }
      chosen = _matchResultCard(reply, cards);
      if (chosen == null) {
        Logger.log('results: no card matched reply "$reply"');
        await narrate(_n.noMatchingResult);
      }
    }
    if (chosen == null) {
      await _fail(_n.errNoListingReply);
      return;
    }
    Logger.log('results: matched "${chosen.title}" at ${chosen.company}');

    await _locateAndAnnounce(chosen.elementId, chosen.title);
    if (!await webView.clickElement(chosen.elementId)) {
      await _fail(_n.applyFormNotFound);
      return;
    }

    // Now on the chosen job's detail page. Still conceptually the same
    // "loading the target" phase that began at the homepage — the FSM
    // only has one TargetLoaded/ContentRead pair, and ContentRead below
    // marks when the JOB's content (not the results page's) was read.
    await _waitForStable();
    dom = await webView.readDom();
    switch (await _handleCaptcha()) {
      case _Outcome.aborted:
        return;
      case _Outcome.confirmed:
        await _waitForStable();
        dom = await webView.readDom();
      case _Outcome.skipped:
        break;
    }
    await fsm.transition(const ContentRead());

    await _narrateListing(dom); // reused as-is (item E)

    await narrate(_n.confirmApply(chosen.title));
    final applyReply = await _gate.listenConfident();
    if (applyReply == null) {
      await _fail(_n.errNoListingReply);
      return;
    }
    if (!isAffirmative(applyReply)) {
      await narrate(_n.listingDeclined);
      await fsm.transition(const FlowReset());
      return;
    }

    if (!await _openApplyForm(dom)) return;

    final formDom = await webView.readDom();
    _fields = _formFields(formDom);
    _profile = await _loadProfile();
    _requireSubmitSuccessSignal = true;
    await fsm.transition(
      ListingConfirmed(
        _fields.map((f) => f.elementId).toList(),
        fieldTypes: {
          for (final f in _fields)
            if (f.type != null) f.elementId: f.type!,
        },
      ),
    );

    if (!await _runFieldLoop()) return;
    await _finalReviewAndSubmit();
  }

  /// Item B: types into VNW's real search bar and submits, or (behind
  /// [AppConfig.liveSearchTyping]) loads a direct results URL for
  /// [query]. Also the fallback when live typing itself fails — one
  /// flag, one code path, per the task's explicit instruction not to
  /// build two separate implementations.
  Future<bool> _openSearchResults(String query) async {
    if (AppConfig.liveSearchTyping) {
      if (await _tryLiveSearch(query)) {
        Logger.log('search: live search bar typing succeeded');
        return true;
      }
      Logger.log('search: live typing failed, falling back to a direct results URL');
    } else {
      Logger.log('search: liveSearchTyping disabled, using a direct results URL');
    }
    return _loadUrl(_directResultsUrl(query));
  }

  Future<bool> _tryLiveSearch(String query) async {
    if (!await _loadUrl(AppConfig.targetUrl)) return false;
    await _waitForStable();
    final dom = await webView.readDom();
    if (dom.searchCandidates.isEmpty) {
      Logger.log('search: no search bar found on the homepage');
      return false;
    }

    final searchBar = dom.searchCandidates.first;
    await _locateAndAnnounce(searchBar.elementId, _n.searchBarLabel);
    if (!(await webView.fillField(searchBar.elementId, query)).success) {
      Logger.log('search: could not type into the search bar');
      return false;
    }

    final submitId = await webView.locateSearchSubmitButton();
    if (submitId == null) {
      Logger.log('search: no search submit button found');
      return false;
    }
    await webView.clickElement(submitId);
    await _waitForStable();
    return true;
  }

  /// VietnamWorks' own query-slug format (e.g. "software engineer" ->
  /// "software-engineer"), confirmed by driving the live search once
  /// while building this — a best-effort guess for non-English queries,
  /// not separately confirmed live (task's accepted VNW-specific
  /// brittleness).
  String _directResultsUrl(String query) {
    final slug = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    return '${AppConfig.targetUrl}/viec-lam?q=${Uri.encodeComponent(slug)}';
  }

  /// Matches the user's full spoken reply (e.g. "I choose X at Y in Z")
  /// against each card's title+company+location by word overlap — see
  /// `FuzzyMatchService.bestMatchByWordOverlap`'s doc for why whole-string
  /// similarity is the wrong tool for this comparison.
  JobResultCard? _matchResultCard(String reply, List<JobResultCard> cards) {
    final labels = cards
        .map((c) => '${c.title} ${c.company} ${c.location}')
        .toList();
    final matched = _fuzzy.bestMatchByWordOverlap(reply, labels);
    if (matched == null) return null;
    return cards[labels.indexOf(matched)];
  }

  /// Item E: locates and clicks VNW's real "Nộp đơn" (apply) button —
  /// already recognized by the existing generic submitCandidates
  /// heuristic (its keyword list already includes "nộp"/"apply") — then
  /// dismisses the AI-resume-optimization upsell modal VNW sometimes
  /// shows before the real apply form appears.
  Future<bool> _openApplyForm(DomSnapshot dom) async {
    if (dom.submitCandidates.isEmpty) {
      Logger.log('apply_click: no apply button found on the job page');
      await _fail(_n.applyFormNotFound);
      return false;
    }
    final applyButton = dom.submitCandidates.first;
    await _locateAndAnnounce(applyButton.elementId, _n.applyButtonLabel);
    if (!await webView.clickElement(applyButton.elementId)) {
      Logger.log('apply_click: could not click the apply button');
      await _fail(_n.applyFormNotFound);
      return false;
    }

    await _waitForStable();
    final dismissed = await webView.dismissApplyUpsell();
    Logger.log('apply_click: upsell modal dismissed=$dismissed');
    await _waitForStable();

    await narrate(_n.openingApplyForm);
    return true;
  }

  /// Final review with the edit loop-back and checkpoint 2, then submit.
  /// Re-entered after a voice retry of a failed submit.
  Future<void> _finalReviewAndSubmit() async {
    while (fsm.state is FinalReviewState) {
      await narrate(_n.finalReview(_summary()));
      final reply = await _gate.listenConfident();
      if (reply == null) return _fail(_n.errNoReviewReply);

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
    await _fail(_n.errNoRequest);
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
    Logger.log('intent: transcript="${accepted?.transcript}" alternatives=${accepted?.alternatives}');
    IntentResult? result;
    Future<bool> attempt() async {
      try {
        result = await ai.parseIntent(
          transcript: accepted?.transcript ?? '',
          alternatives: accepted?.alternatives ?? const [],
          languagePref: language,
        );
        Logger.log(
          'intent: type=${result!.intentType} confidence=${result!.confidence} '
          'targetDescription="${result!.targetDescription}"',
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
      ErrorOccurred(_n.errAiUnavailable, retryAction: attempt),
    );
    if (fsm.state != before) {
      await _reportError();
      return null;
    }
    return result;
  }

  // --- page + listing (milestones 22, 37, 38) -------------------------------

  Future<bool> _loadTarget() => _loadUrl(AppConfig.targetUrl);

  /// Loads [url] in the WebView, retrying once via the FSM's
  /// `ErrorOccurred(retryAction:)` mechanism on failure. Factored out of
  /// the original `_loadTarget()` so the real-target search_job flow can
  /// load the VNW homepage or a direct results URL through the same
  /// retry/error-narration path (item B).
  Future<bool> _loadUrl(String url) async {
    Future<bool> attempt() async {
      try {
        await webView.loadTarget(url);
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
      ErrorOccurred(_n.errPageLoad, retryAction: attempt),
    );
    if (fsm.state == before) return true;
    await _reportError();
    return false;
  }

  /// Waits until the page has stopped changing (no DOM mutation for
  /// [settleDelay], at most [settleMaxWait]) so a single-page app has
  /// finished rendering before it is read.
  Future<void> _waitForStable() async {
    if (settleDelay == Duration.zero) return;
    final quiet = Completer<void>();
    Timer? timer;
    void arm() {
      timer?.cancel();
      timer = Timer(settleDelay, () {
        if (!quiet.isCompleted) quiet.complete();
      });
    }

    final cap = Timer(settleMaxWait, () {
      if (!quiet.isCompleted) quiet.complete();
    });
    final subscription = webView.domChangedEvents.listen((_) => arm());
    arm();
    try {
      await quiet.future;
    } finally {
      await subscription.cancel();
      timer?.cancel();
      cap.cancel();
    }
  }

  /// The fields the per-field loop should ask about: labeled inputs minus
  /// the page's own search box and submit button, and minus input types
  /// the text-fill path cannot fill correctly (hidden, buttons,
  /// checkboxes, radios). A listing page carries plenty of unrelated
  /// inputs (search, newsletter, login) that must not be read out as if
  /// they were the application form.
  List<DomFormField> _formFields(DomSnapshot dom) {
    const skipTypes = {
      'hidden',
      'submit',
      'button',
      'image',
      'reset',
      'checkbox',
      'radio',
    };
    final exclude = {
      for (final f in dom.searchCandidates) f.elementId,
      for (final f in dom.submitCandidates) f.elementId,
    };
    return [
      for (final f in dom.labeledFields)
        if (!exclude.contains(f.elementId) &&
            !skipTypes.contains((f.type ?? '').toLowerCase()))
          f,
    ];
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
      Logger.log('flow: PDF parse failed: ${e.message}');
      await _fail(_n.pdfFailed);
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

  /// Checks for a CAPTCHA. `skipped` = none found, `confirmed` = the user
  /// solved it (by ear via the audio challenge, or otherwise) and said
  /// "continue", `aborted` = the user never resumed.
  Future<_Outcome> _handleCaptcha() async {
    final handler = captchaHandler;
    if (handler == null) return _Outcome.skipped;
    if (!await handler.checkAndHandle(fsm)) return _Outcome.skipped;
    if (fsm.state is! CaptchaPendingState) return _Outcome.confirmed;

    lastNarration = handler.lastSpoken ?? await handler.handOffText();
    notifyListeners();
    for (var i = 0; i < 5; i++) {
      final reply = await _gate.listenConfident();
      if (reply == null) break;
      if (isContinue(reply)) {
        await fsm.transition(const CaptchaResolved());
        return _Outcome.confirmed;
      }
    }
    await _fail(_n.errCaptcha);
    return _Outcome.aborted;
  }

  // --- the per-field loop -----------------------------------------------------

  /// Shared focus-highlight + speak-label utility (item D): outlines
  /// [nodeId] on the real page and speaks [label], without waiting for
  /// speech to finish before returning (the highlight starts alongside
  /// the narration; blocking until TTS fully completes would make every
  /// step feel sluggish). Called from every place the flow acts on a new
  /// element — the search bar, each result card, the matched job's
  /// title, the apply button, and every form field below.
  Future<void> _locateAndAnnounce(String nodeId, String label) async {
    await webView.highlightElement(nodeId);
    unawaited(narrate(label));
  }

  /// Collects, fills and confirms one field.
  Future<_Outcome> _fillOne(
    DomFormField field, {
    required bool offerSaved,
  }) async {
    final label = _labelOf(field);
    await _locateAndAnnounce(field.elementId, label);
    final key = _profileKey(field);

    if (field.type == 'file') return _attachCv(field);

    final value = await _collectValue(
      label,
      offerSaved && key != null ? _profile[key] : null,
    );
    if (value == null) {
      await _fail(_n.errNoAnswer(label));
      return _Outcome.aborted;
    }

    Future<bool> attempt() async =>
        (await webView.fillField(field.elementId, value)).success;

    await narrate(_n.fillingField(label));
    if (!await attempt()) {
      await narrate(_n.fillFailed(label));
      final before = fsm.state;
      await fsm.transition(
        ErrorOccurred(_n.errFill(label), retryAction: attempt),
      );
      if (fsm.state != before) {
        await _reportError();
        return _Outcome.aborted;
      }
    }
    _values[field.elementId] = value;
    return _Outcome.confirmed;
  }

  /// Attaches a CV through the page's own file chooser. Browsers cannot
  /// have a file input set for them, so the CV saved in Settings cannot be
  /// attached automatically — the user picks it again. That switches the
  /// screen to Android's file picker, so it is announced FIRST (a blind
  /// user must not land in an unannounced system screen), and afterwards
  /// the page is asked which file it actually holds before anything is
  /// claimed as attached.
  Future<_Outcome> _attachCv(DomFormField field) async {
    await narrate(_n.cvChooserAnnouncement);
    if (!await webView.triggerFileChooser(field.elementId)) {
      await narrate(_n.cvNone);
      _values[field.elementId] = '-';
      return _Outcome.skipped;
    }
    await awaitFileChooser();

    // The WebView hands the chosen file to the page a moment after the
    // chooser closes, so poll briefly.
    final poll = settleDelay == Duration.zero
        ? Duration.zero
        : const Duration(milliseconds: 400);
    String? name;
    for (var i = 0; i < 4 && name == null; i++) {
      if (i > 0) await Future<void>.delayed(poll);
      name = await webView.getFileInputName(field.elementId);
    }
    if (name == null) {
      await narrate(_n.cvNotAttached);
      _values[field.elementId] = '-';
      return _Outcome.skipped;
    }
    await narrate(_n.cvChosen(name));
    _values[field.elementId] = name;
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
  /// `SubmitConfirmed` in `FinalReviewState`. Throws a [FlowFailure] with a
  /// message in the user's language (the FSM then enters `ErrorState`)
  /// rather than click something it isn't sure about.
  Future<void> submitApplication() async {
    await _waitForStable();
    final dom = await webView.readDom(); // fresh node ids
    final candidates = dom.submitCandidates;
    if (candidates.isEmpty) throw FlowFailure(_n.errSubmitNoButton);

    var pick = candidates.first;
    if (candidates.length > 1) {
      final second = candidates[1];
      final clearlyFirst =
          (pick.heuristicScore ?? 0) > (second.heuristicScore ?? 0);

      ElementMatchResult? match;
      final ai = _ai;
      if (ai != null) {
        try {
          match = await ai.matchElement(
            targetDescription: 'button that submits the job application',
            candidates: candidates,
          );
        } on OpenAiException catch (e) {
          // AI down: fall back to the heuristic ranking alone.
          Logger.log('flow: submit matching failed, using heuristics: $e');
        }
      }
      if (match != null &&
          match.isConfident(AppConstants.elementMatchConfidenceThreshold)) {
        final id = match.elementId;
        pick = candidates.firstWhere((c) => c.elementId == id);
      } else if (!clearlyFirst) {
        throw FlowFailure(_n.errSubmitUnsure);
      }
    }

    await _locateAndAnnounce(pick.elementId, _n.submitButtonLabel);
    if (!await webView.clickElement(pick.elementId)) {
      throw FlowFailure(_n.errSubmitClick);
    }

    if (_requireSubmitSuccessSignal) {
      _requireSubmitSuccessSignal = false; // one-shot
      Logger.log('success_detect: polling for a real success signal');
      if (!await _pollForSubmitSuccess()) {
        Logger.log('success_detect: no success signal within the timeout');
        throw FlowFailure(_n.submitUnconfirmed);
      }
      Logger.log('success_detect: success signal detected');
    }
  }

  /// Item F: polls [WebViewControllerService.detectApplySuccess] a few
  /// times after a real submit click. Only engaged when
  /// [_requireSubmitSuccessSignal] is set (the real-target search_job
  /// flow) — every other caller of [submitApplication] keeps its
  /// original click-and-trust behaviour unchanged.
  Future<bool> _pollForSubmitSuccess() async {
    for (var i = 0; i < 6; i++) {
      if (await webView.detectApplySuccess()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return false;
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
