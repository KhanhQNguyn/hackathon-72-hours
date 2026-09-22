import 'package:flutter_test/flutter_test.dart';
import 'package:job_access_assist/core/language.dart';
import 'package:job_access_assist/core/narration_lookup.dart';
import 'package:job_access_assist/mocks/fake_webview_controller_service.dart';
import 'package:job_access_assist/mocks/scripted_demo_flow.dart';
import 'package:job_access_assist/models/dom_snapshot.dart';
import 'package:job_access_assist/services/tts_service.dart';

class _RecordingTts implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('standalone scripted scenario demo', () {
    late List<JobResultCard> cards;

    setUp(() {
      cards = FakeWebViewControllerService.cannedResultCards;
    });

    test('builds one step per script line, in order', () {
      final steps = buildScenarioDemoScript(cards: cards, chosenCard: cards.first);
      final n = FlowNarration(AppLanguage.en);

      // First line: the command prompt, waiting for the first reply.
      expect(steps.first.line(n), n.commandPrompt);
      expect(steps.first.waitsForReply, isTrue);

      // Last two lines: submitting, then done — no reply expected.
      expect(steps[steps.length - 2].line(n), n.submitting);
      expect(steps.last.line(n), n.done);
      expect(steps.last.waitsForReply, isFalse);
    });

    test('reads back every canned result card, in order', () {
      final steps = buildScenarioDemoScript(cards: cards, chosenCard: cards.first);
      final n = FlowNarration(AppLanguage.en);
      final spoken = steps.map((s) => s.line(n)).toList();

      for (var i = 0; i < cards.length; i++) {
        expect(
          spoken,
          contains(
            n.resultCardLabel(
              i + 1,
              cards[i].title,
              cards[i].company,
              cards[i].location,
            ),
          ),
        );
      }
    });

    test('only the scripted reply points carry a userReply', () {
      final steps = buildScenarioDemoScript(cards: cards, chosenCard: cards.first);
      final withReply = steps.where((s) => s.waitsForReply).length;
      // 31 explicit "B:" turns in the scenario script — every field now
      // gets a "Yes", plus the special cases and the mid-review edit.
      expect(withReply, 31);
    });

    test('ends with an edit-then-confirm exchange instead of a direct confirm', () {
      final steps = buildScenarioDemoScript(cards: cards, chosenCard: cards.first);
      final n = FlowNarration(AppLanguage.en);

      final boxTickedIndex = steps.indexWhere((s) => s.line(n) == n.demoBoxTicked);
      expect(boxTickedIndex, greaterThan(0));
      expect(steps[boxTickedIndex].userReply, 'I want to change Job title to Embedded Engineer');
      expect(steps[boxTickedIndex + 1].line(n), n.parsingIntent);
      expect(
        steps[boxTickedIndex + 2].line(n),
        n.demoFieldChanged('Job title', 'Embedded Engineer'),
      );
      expect(steps[boxTickedIndex + 3].line(n), n.demoConfirmOrEditPrompt);
      expect(steps[boxTickedIndex + 3].userReply, 'Confirm');
    });

    test('runScriptedDemoFlow speaks every line via TtsService, in order', () async {
      final steps = buildScenarioDemoScript(cards: cards, chosenCard: cards.first);
      final n = FlowNarration(AppLanguage.en);
      final tts = _RecordingTts();
      final narrated = <String>[];
      final replies = <String>[];

      await runScriptedDemoFlow(
        steps: steps.take(3).toList(),
        n: n,
        tts: tts,
        onNarration: narrated.add,
        onUserReply: replies.add,
        replyGap: Duration.zero,
        lineGap: Duration.zero,
      );

      expect(tts.spoken, narrated);
      expect(narrated.first, n.commandPrompt);
      expect(replies, ['Software Engineer on VietNamWorks website.']);
    });
  });
}
