import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../widgets/status_narration_view.dart';
import '../widgets/voice_trigger_button.dart';
import 'spike_harness_screen.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StatusNarrationView(text: ''),
              const SizedBox(height: 24),
              const VoiceTriggerButton(),
              // Debug-only entry point to the milestone 01/02 spike
              // harness — not part of the real app flow, gated behind
              // kDebugMode so it never ships in a release build.
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SpikeHarnessScreen(),
                      ),
                    );
                  },
                  child: const Text('Debug: spike harness'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
