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
  static const String targetUrl = 'https://www.vietnamworks.com';

  /// Placeholder PDF path for the flow; the real sample comes with the
  /// listing decision (01-intent.md §7).
  static const String applicationFormPdfPath = 'application_form.pdf';
}
