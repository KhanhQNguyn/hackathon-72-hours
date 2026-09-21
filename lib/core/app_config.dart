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
}
