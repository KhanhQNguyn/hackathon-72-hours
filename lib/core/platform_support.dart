import 'package:flutter/foundation.dart';

/// This is an Android-first build (06-plan.md). The WebView bridge
/// (`WebMessageListener`) and `sqflite` have no Windows/Linux
/// implementation, so on any other platform the app would fail later with
/// confusing platform-interface errors (see docs/intent/audit-2026-09-22.md
/// section 1.1). Detecting it up front lets the app say so plainly.
bool isSupportedPlatform([TargetPlatform? platform]) =>
    !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;
