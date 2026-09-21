import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/narration_lookup.dart';
import '../../orchestration/application_flow_fsm.dart';
import '../widgets/status_narration_view.dart';
import '../widgets/voice_trigger_button.dart';
import 'settings_screen.dart';
import 'spike_harness_screen.dart';

/// Trigger button + live status/narration readout — the entire visible
/// surface of the app during a flow. See spec.md §5 (UI layer, purely
/// presentational, driven by the FSM's current state).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Consumer<ApplicationFlowFsm>(
                builder: (context, fsm, _) =>
                    StatusNarrationView(text: narrationFor(fsm.state)),
              ),
              const SizedBox(height: 24),
              const VoiceTriggerButton(),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                child: const Text('Settings'),
              ),
              // Debug-only entry point to the milestone 01/02 spike
              // harness — not part of the real app flow, gated behind
              // kDebugMode so it never ships in a release build.
              if (kDebugMode) ...[
                const SizedBox(height: 8),
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
