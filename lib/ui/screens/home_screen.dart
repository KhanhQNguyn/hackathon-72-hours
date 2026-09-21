import 'package:flutter/material.dart';

import '../widgets/status_narration_view.dart';
import '../widgets/voice_trigger_button.dart';

/// Trigger button + live status/narration readout — the entire visible
/// surface of the app during a flow. See spec.md §5 (UI layer, purely
/// presentational, driven by the FSM's current state).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: drive StatusNarrationView's text and VoiceTriggerButton's
    // enabled/disabled state from ApplicationFlowFsm's current state via
    // Provider (spec.md §5, plan.md Workstream B2/B5)
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusNarrationView(text: ''),
              SizedBox(height: 24),
              VoiceTriggerButton(),
            ],
          ),
        ),
      ),
    );
  }
}
