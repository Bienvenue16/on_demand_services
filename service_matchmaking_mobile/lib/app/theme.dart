import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_semantic_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF202B5C),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE4E9FB),
      onPrimaryContainer: Color(0xFF2C3B7A),
      secondary: Color(0xFF35479A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEEF1FA),
      onSecondaryContainer: Color(0xFF2C3B7A),
      tertiary: Color(0xFFF0A93B),
      onTertiary: Color(0xFF2A1B04),
      tertiaryContainer: Color(0xFFFFF1DC),
      onTertiaryContainer: Color(0xFFB4680A),
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF1B2140),
      surfaceContainerHighest: Color(0xFFEEF1FA),
      onSurfaceVariant: Color(0xFF5A6078),
      outline: Color(0xFFE3E6F0),
      outlineVariant: Color(0xFFE9EBF3),
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: const Color(0xFFF6F7FB),
      headlineFont: GoogleFonts.sora,
      semanticColors: AppSemanticColors.light,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFF2B441),
      onPrimary: Color(0xFF201804),
      primaryContainer: Color(0xFF2A3140),
      onPrimaryContainer: Color(0xFFF2B441),
      secondary: Color(0xFFF2B441),
      onSecondary: Color(0xFF201804),
      secondaryContainer: Color(0xFF242A36),
      onSecondaryContainer: Color(0xFFC6CBD6),
      tertiary: Color(0xFFF2B441),
      onTertiary: Color(0xFF201804),
      tertiaryContainer: Color(0x24F2B441),
      onTertiaryContainer: Color(0xFFF2B441),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      surface: Color(0xFF1A1F28),
      onSurface: Color(0xFFF4F5F8),
      surfaceContainerHighest: Color(0xFF242A36),
      onSurfaceVariant: Color(0xFF9CA2B0),
      outline: Color(0xFF262C38),
      outlineVariant: Color(0xFF232936),
    );

    return _buildTheme(
      scheme: scheme,
      scaffoldBackground: const Color(0xFF12151B),
      headlineFont: GoogleFonts.spaceGrotesk,
      semanticColors: AppSemanticColors.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required TextStyle Function({TextStyle? textStyle}) headlineFont,
    required AppSemanticColors semanticColors,
  }) {
    final base = ThemeData(brightness: scheme.brightness, useMaterial3: true);
    final bodyTextTheme = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = bodyTextTheme.copyWith(
      displayLarge: headlineFont(textStyle: bodyTextTheme.displayLarge),
      displayMedium: headlineFont(textStyle: bodyTextTheme.displayMedium),
      displaySmall: headlineFont(textStyle: bodyTextTheme.displaySmall),
      headlineLarge: headlineFont(
        textStyle: bodyTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      headlineMedium: headlineFont(
        textStyle: bodyTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      headlineSmall: headlineFont(
        textStyle: bodyTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      titleLarge: headlineFont(
        textStyle: bodyTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      extensions: [semanticColors],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: scheme.brightness == Brightness.dark
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: scheme.onSurface,
        ),
        secondarySelectedColor: scheme.primary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.secondary,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
