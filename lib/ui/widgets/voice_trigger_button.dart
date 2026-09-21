import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../orchestration/application_flow_controller.dart';
import '../../orchestration/application_flow_fsm.dart';

/// The app's single trigger button. Must carry a Semantics label — no
/// exceptions, even on a "temporary" debug button. See spec.md §7,
/// WCAG 3.3.2 (Labels or Instructions) / 4.1.2 (Name, Role, Value).
///
/// Enabled in `IdleState`, and also in `DoneState`/`ErrorState` so a
/// finished or failed run can be restarted (milestone35). While a run is
/// in progress it is disabled, and `Semantics(enabled: ...)` is set
/// explicitly so TalkBack announces that instead of relying on the
/// greyed-out look (WCAG 1.4.1 / 4.1.2).
class VoiceTriggerButton extends StatelessWidget {
  const VoiceTriggerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<ApplicationFlowFsm, bool>(
      (fsm) =>
          fsm.state is IdleState ||
          fsm.state is DoneState ||
          fsm.state is ErrorState,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Start voice command',
      excludeSemantics: true,
      child: FloatingActionButton(
        onPressed: enabled
            ? () => context.read<ApplicationFlowController>().start()
            : null,
        child: const Icon(Icons.mic),
      ),
    );
  }
}
