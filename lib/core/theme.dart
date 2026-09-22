import 'package:flutter/material.dart';

/// Contrast-checked color tokens for the app's own UI.
/// See spec.md §7, WCAG 1.4.3 (Contrast Minimum) and 1.4.11 (Non-text
/// Contrast) — the app's own UI must meet these, even though the app's
/// job is largely perceiving/compensating for a third-party page it
/// doesn't control.
class AppTheme {
  static const Color surfaceBase = Color(0xFF121619);
  static const Color surfaceRaised = Color(0xFF1A1F24);
  static const Color surfaceContainer = Color(0xFF242B30);
  static const Color surfaceBright = Color(0xFF363A3D);
  static const Color outline = Color(0xFF88957F);
  static const Color outlineVariant = Color(0xFF3F4A38);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD5DBDE);
  static const Color textMuted = Color(0xFF9EABB0);
  static const Color listening = Color(0xFF39B00E);
  static const Color processing = Color(0xFF18769E);
  static const Color focusOutline = Color(0xFFFFFF00);
  static const Color statusError = Color(0xFFFF5252);

  static ThemeData get theme {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: listening,
      onPrimary: Color(0xFF0B3900),
      primaryContainer: Color(0xFF39B00E),
      onPrimaryContainer: Color(0xFF0B3A00),
      secondary: Color(0xFF83D0FC),
      onSecondary: Color(0xFF00344A),
      secondaryContainer: Color(0xFF006D95),
      onSecondaryContainer: Color(0xFFC8E9FF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: surfaceBase,
      onSurface: Color(0xFFE0E3E7),
    );

    const roundedSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    const roundedMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceBase,
      canvasColor: surfaceBase,
      dividerColor: outlineVariant,
      iconTheme: const IconThemeData(color: textSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceBase,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 32, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.64, color: textPrimary),
        titleLarge: TextStyle(fontSize: 26, height: 1.31, fontWeight: FontWeight.w700, letterSpacing: -0.26, color: textPrimary),
        titleMedium: TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w700, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 18, height: 1.56, fontWeight: FontWeight.w500, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: textSecondary),
        labelLarge: TextStyle(fontSize: 16, height: 1.38, fontWeight: FontWeight.w700, letterSpacing: 0.32),
        labelMedium: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w600, letterSpacing: 0.56),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: roundedMedium.copyWith(side: const BorderSide(color: outlineVariant, width: 1.5)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: inputBorder.copyWith(borderSide: const BorderSide(color: outlineVariant, width: 1.5)),
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: focusOutline, width: 3)),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: statusError, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: roundedMedium,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: textPrimary,
          side: const BorderSide(color: outline, width: 1.5),
          shape: roundedSmall,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceBright,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 16),
        shape: roundedSmall,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
