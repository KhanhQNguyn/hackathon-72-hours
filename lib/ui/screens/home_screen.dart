import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/narration_lookup.dart';
import '../../core/theme.dart';
import '../../orchestration/application_flow_controller.dart';
import '../../orchestration/application_flow_fsm.dart';
import '../widgets/job_page_view.dart';
import '../widgets/status_narration_view.dart';
import '../widgets/voice_trigger_button.dart';
import 'settings_screen.dart';
import 'spike_harness_screen.dart';

/// The app's single task surface. It mirrors the FSM and spoken narration in
/// one predictable reading order, with settings as the sole top-level route.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.showWebView = false});

  /// A real run needs the embedded page in the widget tree for the WebView
  /// controller to load and inspect it. Mock runs deliberately omit it.
  final bool showWebView;

  @override
  Widget build(BuildContext context) {
    final language = context.select<ApplicationFlowController, String>(
      (c) => c.language,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.record_voice_over_outlined, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Job Access Assist',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.tune_outlined),
                label: Text(FlowNarration(language).settingsButton),
              ),
            ),
            const SizedBox(height: 28),
            Consumer2<ApplicationFlowFsm, ApplicationFlowController>(
              builder: (context, fsm, controller, _) {
                final visual = _statusVisual(fsm.state);
                return StatusNarrationView(
                  text: controller.lastNarration.isNotEmpty
                      ? controller.lastNarration
                      : narrationFor(fsm.state, language: controller.language),
                  icon: visual.icon,
                  accentColor: visual.color,
                );
              },
            ),
            const SizedBox(height: 24),
            const VoiceTriggerButton(),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SpikeHarnessScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.science_outlined),
                label: const Text('Debug: spike harness'),
              ),
            ],
            if (showWebView) ...[
              const SizedBox(height: 24),
              Text('Job page', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const SizedBox(height: 480, child: JobPageView()),
            ],
          ],
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _statusVisual(ApplicationFlowState state) {
  if (state is ListeningState) {
    return (icon: Icons.hearing, color: AppTheme.listening);
  }
  if (state is ParsingIntentState ||
      state is LoadingTargetState ||
      state is ReadingContentState ||
      state is RetryingState) {
    return (icon: Icons.sync, color: AppTheme.processing);
  }
  if (state is DoneState) {
    return (icon: Icons.check_circle_outline, color: AppTheme.listening);
  }
  if (state is ErrorState) {
    return (icon: Icons.error_outline, color: AppTheme.statusError);
  }
  if (state is CaptchaPendingState) {
    return (icon: Icons.pause_circle_outline, color: AppTheme.focusOutline);
  }
  if (state is FinalReviewState ||
      state is EditingFieldState ||
      state is AwaitingSubmitConfirmationState ||
      state is AwaitingUserActionState ||
      state is FillingFormState) {
    return (icon: Icons.fact_check_outlined, color: AppTheme.processing);
  }
  return (icon: Icons.mic_none_outlined, color: AppTheme.textMuted);
}
