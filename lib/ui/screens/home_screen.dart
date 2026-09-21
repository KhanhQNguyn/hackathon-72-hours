import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/narration_lookup.dart';
import '../../orchestration/application_flow_controller.dart';
import '../../orchestration/application_flow_fsm.dart';
import '../widgets/job_page_view.dart';
import '../widgets/status_narration_view.dart';
import '../widgets/voice_trigger_button.dart';
import 'settings_screen.dart';
import 'spike_harness_screen.dart';

/// Trigger button + live status/narration readout — the entire visible
/// surface of the app during a flow. See spec.md §5 (UI layer, purely
/// presentational, driven by the FSM's current state).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.showWebView = false});

  /// Show the embedded job page below the controls. On only for a real
  /// (non-mock) run, where the WebView must be in the tree for the flow to
  /// load and read the page (milestone44).
  final bool showWebView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: showWebView
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              // Mirrors the last spoken line; before anything has been said
              // it falls back to the state's placeholder text.
              Consumer2<ApplicationFlowFsm, ApplicationFlowController>(
                builder: (context, fsm, controller, _) => StatusNarrationView(
                  text: controller.lastNarration.isNotEmpty
                      ? controller.lastNarration
                      : narrationFor(fsm.state, language: controller.language),
                ),
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
              if (showWebView) const Expanded(child: JobPageView()),
            ],
          ),
        ),
      ),
    );
  }
}
