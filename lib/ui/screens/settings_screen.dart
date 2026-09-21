import 'package:flutter/material.dart';

/// Language toggle (EN/VI), persisted via `PreferencesService`. See
/// spec.md §8.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: EN/VI toggle wired to PreferencesService.setLanguagePref
    // (plan.md Workstream B4)
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('TODO: language toggle (EN/VI)')),
    );
  }
}
