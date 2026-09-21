import 'package:flutter/material.dart';

import '../../core/language.dart';
import '../../core/narration_lookup.dart';
import '../../core/theme.dart';

/// Shown instead of the app on a non-Android platform. Bilingual, since no
/// language preference can be read here (its storage is one of the things
/// that does not work on these platforms).
class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final en = FlowNarration(AppLanguage.en).unsupportedPlatform;
    final vi = FlowNarration(AppLanguage.vi).unsupportedPlatform;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(Icons.android_outlined, size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      en,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      vi,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
