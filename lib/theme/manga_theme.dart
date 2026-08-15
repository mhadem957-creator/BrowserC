import 'package:flutter/material.dart';

/// Manga / Inked Aesthetics (Neubrutalism) design system.
///
/// Paper background, thick ink borders, hard offset shadows, and crimson accents.
class MangaTheme {
  MangaTheme._();

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color paper = Color(0xFFF6F5F0); // Authentic manga paper
  static const Color ink = Color(0xFF121212); // Heavy ink black
  static const Color crimson = Color(0xFFE60012); // Accent / active / alert
  static const Color paperDark = Color(0xFFE8E6DF);
  static const Color inkLight = Color(0xFF2A2A2A);

  // ── Borders & Shadows ────────────────────────────────────────────────────
  static const double borderWidth = 3.0;
  static const double borderWidthThick = 4.0;
  static const Offset shadowOffset = Offset(4, 4);
  static const Offset shadowOffsetHeavy = Offset(5, 5);

  static BoxShadow get hardShadow => const BoxShadow(
        color: ink,
        offset: shadowOffset,
        blurRadius: 0,
        spreadRadius: 0,
      );

  static BoxShadow get hardShadowHeavy => const BoxShadow(
        color: ink,
        offset: shadowOffsetHeavy,
        blurRadius: 0,
        spreadRadius: 0,
      );

  static Border get thickBorder => Border.all(color: ink, width: borderWidth);

  static Border get thickBorderHeavy =>
      Border.all(color: ink, width: borderWidthThick);

  // ── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto', // System fallback; can be swapped for a comic font later
    );

    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: const ColorScheme.light(
        primary: crimson,
        onPrimary: paper,
        secondary: ink,
        onSecondary: paper,
        surface: paper,
        onSurface: ink,
        error: crimson,
        onError: paper,
        outline: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: ink, size: 24),
      ),
      bottomAppBarTheme: const BottomAppBarTheme(
        color: paper,
        elevation: 0,
        height: 64,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: crimson,
          foregroundColor: paper,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: ink, width: borderWidth),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: ink, width: borderWidth),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: ink, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: ink, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: crimson, width: borderWidth),
        ),
        hintStyle: TextStyle(color: ink.withOpacity(0.45)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: ink, width: borderWidthThick),
        ),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: const TextStyle(color: ink, fontSize: 15),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: paper, fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: crimson,
        linearTrackColor: paperDark,
      ),
      dividerTheme: const DividerThemeData(
        color: ink,
        thickness: 2,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: ink, size: 24),
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ).copyWith(
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyLarge: const TextStyle(fontWeight: FontWeight.w500, color: ink),
        bodyMedium: const TextStyle(color: ink),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: ink,
        ),
      ),
      cardTheme: CardTheme(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: ink, width: borderWidth),
        ),
        margin: const EdgeInsets.all(8),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return crimson;
          return ink;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return crimson.withOpacity(0.35);
          }
          return paperDark;
        }),
        trackOutlineColor: MaterialStateProperty.all(ink),
        trackOutlineWidth: MaterialStateProperty.all(2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return crimson;
          return paper;
        }),
        checkColor: MaterialStateProperty.all(paper),
        side: const BorderSide(color: ink, width: 2.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}
