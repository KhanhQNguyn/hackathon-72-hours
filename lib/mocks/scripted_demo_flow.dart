import 'dart:async';

import '../core/narration_lookup.dart';
import '../core/voice_replies.dart';
import '../models/dom_snapshot.dart';
import '../services/tts_service.dart';
import '../utils/logger.dart';

/// One line of the standalone scripted scenario demo (debug-only): a
/// pre-written "play script" recited verbatim, not derived from any real
/// DOM read, AI call, or STT capture — the whole point is a reliable,
/// deterministic run for a pitch/demo. See `AppConfig.debugScenarioDemo`.
///
/// [waitForReply] marks the handful of points the script itself shows an
/// explicit `B:` line — only those pause for [ScriptedDemoStep.replyGap];
/// every other line just narrates and moves on (matching the script's own
/// pacing, not a fixed per-line delay).
class ScriptedDemoStep {
  final String Function(FlowNarration n) line;

  /// What "B" nominally says at this point, for the transcript/log only —
  /// never parsed or acted on (per the scenario's own instruction: this is
  /// a scripted play, not a real-time simulation).
  final String? userReply;

  const ScriptedDemoStep(this.line, {this.userReply});

  bool get waitsForReply => userReply != null;

  static const Duration replyGap = Duration(seconds: 5);

  /// Pause between consecutive narrated lines that don't wait for a
  /// reply — enough for the lines not to blur together, short enough to
  /// keep the demo moving.
  static const Duration lineGap = Duration(milliseconds: 500);
}

/// Builds the full ordered script matching the scenario exactly, from
/// [cards] (so the 5 results lines stay in sync with whatever
/// `FakeWebViewControllerService.cannedResultCards` currently holds)
/// and the chosen job's title.
List<ScriptedDemoStep> buildScenarioDemoScript({
  required List<JobResultCard> cards,
  required JobResultCard chosenCard,
}) {
  final replies = scenarioDemoUserReplies;
  var replyIndex = 0;
  String nextReply() => replies[replyIndex++];

  return [
    ScriptedDemoStep((n) => n.commandPrompt, userReply: nextReply()),
    ScriptedDemoStep((n) => n.parsingIntent),
    ScriptedDemoStep((n) => n.demoSearching('Software Engineer')),
    ScriptedDemoStep((n) => n.resultsFound(cards.length)),
    for (var i = 0; i < cards.length; i++)
      ScriptedDemoStep(
        (n) => n.resultCardLabel(
          i + 1,
          cards[i].title,
          cards[i].company,
          cards[i].location,
        ),
      ),
    ScriptedDemoStep((n) => n.confirmListing, userReply: nextReply()),
    ScriptedDemoStep((n) => n.whichResult, userReply: nextReply()),
    ScriptedDemoStep((n) => n.loadingPage),
    ScriptedDemoStep((n) => n.readingPage),
    ScriptedDemoStep((n) => n.demoPdfFound),
    ScriptedDemoStep((n) => n.working),
    ScriptedDemoStep((n) => n.demoJobDescriptionIntro),
    ScriptedDemoStep((n) => n.demoJobDescriptionText),
    ScriptedDemoStep(
      (n) => n.confirmApply(chosenCard.title),
      userReply: nextReply(),
    ),
    ScriptedDemoStep((n) => n.demoUpsellPrompt, userReply: nextReply()),
    ScriptedDemoStep((n) => n.readingForm),
    ScriptedDemoStep((n) => n.demoCvAutoAttach('my_portfolio.pdf')),
    ScriptedDemoStep((n) => n.demoCvUploaded),
    ScriptedDemoStep((n) => n.reviewHeading),

    // Profile fields — pre-filled, confirm-or-edit pattern. Every field
    // now waits for an explicit "Yes" (the scenario's own pacing choice —
    // a real 5s gap at each one, not just the special cases).
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('First name', 'Hoang'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Last name', 'Minh'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Job title', 'Full Stack Developer'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Current job level', 'Intern/Student'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Years of experience', '2'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Highest Education', 'Bachelors'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Current job function', 'Software Developer'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Current industry', 'Education/Training'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldMissing('Current salary'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Cell number', '0981197605'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Date of birth', '05/01/2006'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Nationality', 'Local Vietnamese'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Gender', 'Male'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Marital Status', 'Single'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Country', 'Vietnam/Ho Chi Minh/Binh Thanh'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Address', 'Ho Chi Minh city, vietnam'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep((n) => n.demoSection('Working preference')),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Expect location', 'Ho Chi Minh'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoOptionalMultiChoice('5 expected benefit'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoExpectedSalaryPrompt,
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Expected job level', 'Intern/Student'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep((n) => n.demoShowSalaryToggle, userReply: nextReply()),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Expected job function', 'Software Developer'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoFieldConfirm('Expected Industry', 'Education/Training'),
      userReply: nextReply(),
    ),
    ScriptedDemoStep(
      (n) => n.demoPrivacyPolicyPrompt,
      userReply: nextReply(),
    ),
    // The user edits a field instead of confirming straight away — a
    // loop-back, mirroring the real flow's "edit FIELD" mechanism.
    ScriptedDemoStep((n) => n.demoBoxTicked, userReply: nextReply()),
    ScriptedDemoStep((n) => n.parsingIntent),
    ScriptedDemoStep(
      (n) => n.demoFieldChanged('Job title', 'Embedded Engineer'),
    ),
    ScriptedDemoStep((n) => n.demoConfirmOrEditPrompt, userReply: nextReply()),

    ScriptedDemoStep((n) => n.submitting),
    ScriptedDemoStep((n) => n.done),
  ];
}

/// Plays [steps] through [tts], calling [onNarration] with each line (for
/// an on-screen live-region caption, mirroring the real flow's
/// `lastNarration`) and [onUserReply] whenever a step has a scripted
/// reply (for a "transcript" log/caption of what "B" says). Awaits [n]'s
/// language directly — the demo doesn't react to a language change
/// mid-run, since restarting is cheap and expected between demo takes.
Future<void> runScriptedDemoFlow({
  required List<ScriptedDemoStep> steps,
  required FlowNarration n,
  required TtsService tts,
  void Function(String text)? onNarration,
  void Function(String text)? onUserReply,
  Duration replyGap = ScriptedDemoStep.replyGap,
  Duration lineGap = ScriptedDemoStep.lineGap,
}) async {
  Logger.log('demo: starting scripted scenario (${steps.length} lines)');
  for (final step in steps) {
    final text = step.line(n);
    Logger.log('demo: A: $text');
    onNarration?.call(text);
    try {
      await tts.speak(text);
    } catch (e) {
      Logger.log('demo: tts failed: $e');
    }

    final reply = step.userReply;
    if (reply != null) {
      Logger.log('demo: B: $reply');
      onUserReply?.call(reply);
      await Future<void>.delayed(replyGap);
    } else {
      await Future<void>.delayed(lineGap);
    }
  }
  Logger.log('demo: scripted scenario finished');
}
