import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/narration_lookup.dart';
import '../../orchestration/application_flow_controller.dart';
import '../../orchestration/application_flow_fsm.dart';

/// The app's single trigger button. Must carry a Semantics label — no
/// exceptions, even on a "temporary" debug button. See spec.md §7,
/// WCAG 3.3.2 (Labels or Instructions) / 4.1.2 (Name, Role, Value).
///
/// Three visibly different states, each differing by icon AND colour (never
/// colour alone, WCAG 1.4.1):
/// - ready: `mic`, primary colour — enabled in `IdleState`, and also in
///   `DoneState`/`ErrorState` so a finished or failed run can be restarted;
/// - listening: `hearing`, red — while the recognizer is open;
/// - unavailable: `mic_off`, grey — a run is in progress.
///
/// "Listening" comes from `ApplicationFlowController.isListening`, not the
/// FSM state: the mic is also open during the in-flow confirmations while
/// the FSM sits in `FillingForm`/`FinalReview`. The same signal drives the
/// spoken start/stop cues, so the visual and audio cues cannot disagree.
///
/// The semantics label changes with the state so TalkBack announces it, and
/// `enabled` is set explicitly so a disabled button is announced as such
/// rather than only looking greyed out (WCAG 4.1.2).
class VoiceTriggerButton extends StatelessWidget {
  const VoiceTriggerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ready = context.select<ApplicationFlowFsm, bool>(
      (fsm) =>
          fsm.state is IdleState ||
          fsm.state is DoneState ||
          fsm.state is ErrorState,
    );
    final view = context
        .select<ApplicationFlowController, ({bool listening, String language})>(
          (c) => (listening: c.isListening, language: c.language),
        );
    final n = FlowNarration(view.language);
    final IconData icon;
    final Color background;
    final Color foreground;
    final String label;
    if (view.listening) {
      icon = Icons.hearing;
      background = AppTheme.listening;
      foreground = const Color(0xFF0B3900);
      label = n.micLabelListening;
    } else if (ready) {
      icon = Icons.mic;
      background = AppTheme.surfaceContainer;
      foreground = AppTheme.textPrimary;
      label = n.micLabelIdle;
    } else {
      icon = Icons.mic_off;
      background = AppTheme.surfaceBright;
      foreground = AppTheme.textMuted;
      label = n.working;
    }

    final enabled = ready && !view.listening;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
          onPressed: enabled
              ? () => context.read<ApplicationFlowController>().start()
              : null,
          icon: Icon(icon, size: 28),
          label: Text(label),
        ),
      ),
    );
  }
}
