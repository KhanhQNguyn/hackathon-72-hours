import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../orchestration/application_flow_fsm.dart';
import '../../orchestration/voice_command_gate.dart';
import '../../services/preferences_service.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';

/// The app's single trigger button. Must carry a Semantics label — no
/// exceptions, even on a "temporary" debug button. See spec.md §7,
/// WCAG 3.3.2 (Labels or Instructions) / 4.1.2 (Name, Role, Value).
///
/// Enabled only in `IdleState`. `Semantics(enabled: ...)` is set
/// explicitly so TalkBack announces the disabled state instead of relying
/// on the greyed-out look (WCAG 1.4.1 / 4.1.2).
class VoiceTriggerButton extends StatelessWidget {
  const VoiceTriggerButton({super.key});

  Future<void> _onPressed(BuildContext context) async {
    final fsm = context.read<ApplicationFlowFsm>();
    final gate = VoiceCommandGate(
      fsm: fsm,
      speech: context.read<SpeechService>(),
      tts: context.read<TtsService>(),
      preferences: context.read<PreferencesService>(),
    );
    await fsm.transition(const TriggerPressed());
    if (fsm.state is ListeningState) {
      await gate.run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<ApplicationFlowFsm, bool>(
      (fsm) => fsm.state is IdleState,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Start voice command',
      excludeSemantics: true,
      child: FloatingActionButton(
        onPressed: enabled ? () => _onPressed(context) : null,
        child: const Icon(Icons.mic),
      ),
    );
  }
}
