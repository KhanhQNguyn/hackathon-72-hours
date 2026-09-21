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
  final IconData icon;
  final Color accentColor;

  const StatusNarrationView({
    super.key,
    required this.text,
    this.icon = Icons.record_voice_over_outlined,
    this.accentColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, color: accentColor, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
