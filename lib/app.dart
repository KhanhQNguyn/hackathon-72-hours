import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'orchestration/application_flow_fsm.dart';
import 'ui/screens/home_screen.dart';

/// MaterialApp root widget. See spec.md §5 (UI layer is MVVM, with the
/// FSM as the "ViewModel", exposed here via `provider`).
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApplicationFlowFsm(),
      child: MaterialApp(
        title: 'Job Access Assist',
        theme: AppTheme.theme,
        home: const HomeScreen(),
      ),
    );
  }
}
