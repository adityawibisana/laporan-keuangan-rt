import 'package:flutter/material.dart';

/// App theme: a minimal, clean "banking app" look built on a teal / emerald
/// seed. The aesthetic favours whitespace and hairline dividers over boxed,
/// bordered cards, with a single accent colour (teal) carrying the brand.
class AppTheme {
  AppTheme._();

  /// Teal / emerald brand seed.
  static const Color seed = Color(0xFF00897B);

  /// Semantic accents for money in/out. Kept distinct from the teal brand so
  /// income vs. expense stays readable at a glance.
  static const Color income = Color(0xFF2E7D32);
  static const Color expense = Color(0xFFC62828);

  /// Monospace family (registered in pubspec) used for every money figure so
  /// digits are even-width and right-aligned amounts line up.
  static const String monoFamily = 'RobotoMono';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    // Subtle neutral page background so the white cards lift off it with their
    // soft shadows (a flat white-on-white card would be invisible).
    const pageBackground = Color(0xFFF2F5F5);

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: pageBackground,
    );

    return base.copyWith(
      // Flat app bar that blends into the page background — no heavy elevation.
      appBarTheme: AppBarTheme(
        backgroundColor: pageBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      // Hairline dividers are the primary separator in this design.
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// A copy of [base] rendered in the monospace money family. Use for any
  /// rupiah figure so columns of amounts stay aligned.
  static TextStyle money(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: monoFamily,
        // Even-width digits.
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
