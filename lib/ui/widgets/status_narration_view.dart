import 'package:flutter/material.dart';

/// Visible text mirror of everything being spoken — never audio-only.
/// Must be a `Semantics(liveRegion: true)` region so TalkBack announces
/// status changes even if TTS narration fails or is muted. See spec.md
/// §7 (WCAG 3.3.1 Error Identification) and the accessibility-wcag.md
/// live-region cross-check.
///
/// Text is supplied by the caller (`home_screen.dart` binds it to the FSM
/// state via `narrationFor`).
class StatusNarrationView extends StatelessWidget {
  final String text;

  const StatusNarrationView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
