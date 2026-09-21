import 'package:flutter/material.dart';

/// Contrast-checked color tokens for the app's own UI.
/// See spec.md §7, WCAG 1.4.3 (Contrast Minimum) and 1.4.11 (Non-text
/// Contrast) — the app's own UI must meet these, even though the app's
/// job is largely perceiving/compensating for a third-party page it
/// doesn't control.
class AppTheme {
  // TODO: define the actual contrast-checked palette (spec.md §7) —
  // do not invent color values here; check them with a contrast tool
  // (10-accessibility-wcag.md) before committing to real ones.
  static ThemeData get theme => ThemeData();
}
