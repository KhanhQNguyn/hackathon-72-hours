import 'package:flutter/material.dart';

/// The app's single trigger button. Must carry a Semantics label — no
/// exceptions, even on a "temporary" debug button. See spec.md §7,
/// WCAG 3.3.2 (Labels or Instructions) / 4.1.2 (Name, Role, Value).
class VoiceTriggerButton extends StatelessWidget {
  const VoiceTriggerButton({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: wire onPressed to ApplicationFlowFsm's TriggerPressed event
    // (plan.md Workstream B2)
    return Semantics(
      button: true,
      label: 'Start voice command',
      child: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.mic),
      ),
    );
  }
}
