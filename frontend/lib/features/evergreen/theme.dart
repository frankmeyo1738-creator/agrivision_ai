import 'package:flutter/material.dart';

abstract final class EvergreenColors {
  static const forest = Color(0xFF163D2E);
  static const deep = Color(0xFF102D23);
  static const leaf = Color(0xFF3F8665);
  static const sage = Color(0xFFB9D7BF);
  static const soft = Color(0xFFE6F0E7);
  static const canvas = Color(0xFFF7F8F3);
  static const ink = Color(0xFF20352B);
  // The requested #748178 remains a decorative token. Body text uses a
  // deeper shade to meet normal-text contrast on the warm canvas.
  static const secondary = Color(0xFF56645C);
  static const muted = Color(0xFF748178);
  static const border = Color(0xFFE2E8DF);
  static const healthy = Color(0xFF328568);
  static const warning = Color(0xFFD69A43);
  static const critical = Color(0xFFB75C4D);
  static const warningText = Color(0xFF765018);
  static const criticalText = Color(0xFF8B4035);
}

abstract final class EvergreenTheme {
  static ThemeData get light => _theme(false);
  static ThemeData get dark => _theme(true);
  static ThemeData _theme(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: EvergreenColors.forest,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? EvergreenColors.sage : EvergreenColors.forest,
      onPrimary: dark ? EvergreenColors.deep : Colors.white,
      primaryContainer: dark ? const Color(0xFF284635) : EvergreenColors.soft,
      onPrimaryContainer: dark
          ? const Color(0xFFDFECDD)
          : EvergreenColors.forest,
      surface: dark ? const Color(0xFF1A3026) : Colors.white,
      onSurface: dark ? const Color(0xFFEEF4EB) : EvergreenColors.ink,
      onSurfaceVariant: dark
          ? const Color(0xFFB7C8BB)
          : EvergreenColors.secondary,
      error: dark ? const Color(0xFFF2B2A6) : EvergreenColors.criticalText,
    );
    final text = TextTheme(
      displaySmall: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -1.3,
      ),
      headlineLarge: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -.8,
      ),
      headlineMedium: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.55),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.5),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF10221A)
          : EvergreenColors.canvas,
      dividerColor: dark ? const Color(0xFF314A3A) : EvergreenColors.border,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: dark ? const Color(0xFF354E3E) : EvergreenColors.soft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        height: 72,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        tilePadding: EdgeInsets.zero,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 350),
      ),
    );
  }
}
