/// Build-time switches for the pre-integration phase.
class AppConfig {
  /// While true (the default until milestone 44), `App` wires the fake
  /// WebView/PDF services from `lib/mocks/` so the whole voice flow can be
  /// exercised without a real page (milestone35). Milestone 44 flips the
  /// default; `--dart-define=USE_MOCK_SERVICES=false` selects the real
  /// services in the meantime.
  static const bool useMockServices = bool.fromEnvironment(
    'USE_MOCK_SERVICES',
    defaultValue: true,
  );

  /// The confirmed target platform (01-intent.md §5). The specific listing
  /// is still an open question (§7); replace when the team picks one.
  /// Override with `--dart-define=TARGET_URL=https://...` to point a run
  /// at one specific listing page.
  static const String targetUrl = String.fromEnvironment(
    'TARGET_URL',
    defaultValue: 'https://www.vietnamworks.com',
  );

  /// PDF path used by mocked runs. On a real run the user picks the file
  /// (there is no listing-to-PDF link to follow yet, 01-intent.md §7).
  static const String applicationFormPdfPath = 'application_form.pdf';

  /// Real-target demo flow (search_job intent), item B. When true (the
  /// default), the flow types into VietnamWorks' real search bar and
  /// clicks its real search button. When false, it skips straight to a
  /// results URL built from the query, bypassing the live-typing step —
  /// the fallback to flip if the search bar proves flaky close to the
  /// deadline. `--dart-define=LIVE_SEARCH_TYPING=false` to disable.
  static const bool liveSearchTyping = bool.fromEnvironment(
    'LIVE_SEARCH_TYPING',
    defaultValue: true,
  );

  /// Debug-only: when true (and only combined with [useMockServices]),
  /// replaces the real speech recognizer with a canned script of replies
  /// matching the real-target demo scenario, so the flow can be watched
  /// end-to-end on a real device without depending on the on-device
  /// recognizer correctly capturing a full sentence.
  /// `--dart-define=DEBUG_SCRIPTED_VOICE=true` to enable.
  static const bool debugScriptedVoice = bool.fromEnvironment(
    'DEBUG_SCRIPTED_VOICE',
    defaultValue: false,
  );

  /// Debug-only: shows a button that plays the standalone scripted
  /// scenario demo (`lib/mocks/scripted_demo_flow.dart`) — a literal,
  /// pre-written "play script" recited via TTS, entirely independent of
  /// the FSM/controller/real AI. `--dart-define=DEBUG_SCENARIO_DEMO=true`
  /// to enable.
  static const bool debugScenarioDemo = bool.fromEnvironment(
    'DEBUG_SCENARIO_DEMO',
    defaultValue: false,
  );
}
