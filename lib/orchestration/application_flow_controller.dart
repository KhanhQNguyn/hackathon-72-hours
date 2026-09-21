import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/flow_narration.dart';
import '../core/voice_replies.dart';
import '../models/dom_snapshot.dart';
import '../services/applicant_profile_service.dart';
import '../services/file_picker_service.dart';
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
import 'voice_command_gate.dart';

enum _Outcome { confirmed, skipped, aborted }

/// Drives one complete run of the flow — the "orchestrating caller" the
/// FSM's own comments refer to. It sequences the services and fires FSM
/// events; the FSM stays the single source of truth for *where* the flow
/// is, and the only place the real submit action can fire.
///
/// ```
/// trigger -> spoken command -> load page -> read listing (+ CAPTCHA
/// check) -> confirm listing (checkpoint 1) -> read form PDF ->
/// per-field confirm loop -> final review (edit loop) -> confirm
/// (checkpoint 2) -> submit -> done
/// ```
///
/// Every spoken line is also published in [lastNarration] so the on-screen
/// status text mirrors the audio (WCAG 3.3.1, spec.md §7).
///
/// Milestone 35 stand-ins, replaced later: the spoken command is not
/// parsed (milestone 36), images without alt text are only counted
/// (milestone 37), the listing text is read verbatim rather than
/// summarized (milestone 38), and fields are matched to the saved profile
/// by keyword (milestones 39/41).
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
  }) {
    _gate = VoiceCommandGate(
      fsm: fsm,
      speech: speech,
      tts: tts,
      preferences: preferences,
      narrate: narrate,
    );
  }

  final ApplicationFlowFsm fsm;
  final TtsService tts;
  final PreferencesService preferences;
  final WebViewControllerService webView;
  final PdfReaderService pdfReader;
  final ApplicantProfileService profileService;
  final FilePickerService filePicker;
  final CaptchaCheckpointHandler? captchaHandler;

  late final VoiceCommandGate _gate;
  bool _running = false;
  Map<String, String> _profile = {};
  final Map<String, String> _values = {};
  List<DomFormField> _fields = [];
  FlowNarration _n = FlowNarration('en');

  /// Text of the most recent spoken line ('' before the first one).
  String lastNarration = '';

  bool get isRunning => _running;

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

  Future<void> _refreshNarration() async {
    _n = FlowNarration(await preferences.getLanguagePref());
  }

  Future<void> _run() async {
    await _refreshNarration();
    await fsm.transition(const TriggerPressed());
    await narrate(_n.commandPrompt);
    await _gate.run();
    if (fsm.state is! ParsingIntentState) return _reportError();

    // Milestone 36 parses the command; until then any accepted command
    // means "read this listing and apply".
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

    // Checkpoint 1: the user confirms this is the right listing.
    await narrate(
      _n.listingSummary(
        text: _clip(dom.visibleText, 400),
        imagesWithoutAlt: dom.images.where((i) => !i.hasAlt).length,
      ),
    );
    await narrate(_n.confirmListing);
    final listingReply = await _gate.listenConfident();
    if (listingReply == null) return _fail('No response to the listing question.');
    if (!isAffirmative(listingReply)) {
      await narrate(_n.listingDeclined);
      await fsm.transition(const FlowReset());
      return;
    }

    await narrate(_n.readingForm);
    try {
      final formText = await pdfReader.extractTextWithOcrFallback(
        AppConfig.applicationFormPdfPath,
      );
      await narrate(_n.formText(_clip(formText, 400)));
    } on PdfParseException catch (e) {
      await narrate(_n.pdfFailed);
      return _fail(e.message);
    }

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
        final field = _matchField(target);
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
    await narrate(_n.pageLoadFailed);
    final before = fsm.state;
    await fsm.transition(
      ErrorOccurred('The page did not load.', retryAction: attempt),
    );
    if (fsm.state == before) return true;
    await _reportError();
    return false;
  }

  /// Checks for a CAPTCHA (checkpoint 3). `skipped` = none found,
  /// `confirmed` = handled (audio challenge, or user solved it and said
  /// "continue"), `aborted` = the user never resumed.
  Future<_Outcome> _handleCaptcha() async {
    final handler = captchaHandler;
    if (handler == null) return _Outcome.skipped;
    if (!await handler.checkAndHandle(fsm)) return _Outcome.skipped;
    if (fsm.state is! CaptchaPendingState) return _Outcome.confirmed;

    lastNarration = CaptchaCheckpointHandler.handOffNarration;
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

  /// Collects, fills and confirms one field.
  Future<_Outcome> _fillOne(
    DomFormField field, {
    required bool offerSaved,
  }) async {
    final label = _labelOf(field);
    final key = _profileKey(field);

    if (field.type == 'file') return _attachCv(field, label);

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
    await narrate(_n.filled(label));
    return _Outcome.confirmed;
  }

  Future<_Outcome> _attachCv(DomFormField field, String label) async {
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

  DomFormField? _matchField(String target) {
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
