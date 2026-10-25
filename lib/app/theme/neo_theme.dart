import 'package:flutter/material.dart';

class NeoPalette {
  const NeoPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.highlight,
    required this.text,
    required this.border,
    required this.shadow,
    required this.muted,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color highlight;
  final Color text;
  final Color border;
  final Color shadow;
  final Color muted;

  static const light = NeoPalette(
    background: Color(0xFFF7F4EA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFFB8F56A),
    secondary: Color(0xFFFF6B4A),
    accent: Color(0xFFA7C7FF),
    highlight: Color(0xFFFFD84D),
    text: Color(0xFF171717),
    border: Color(0xFF171717),
    shadow: Color(0xFF171717),
    muted: Color(0xFF5D5A52),
  );

  static const dark = NeoPalette(
    background: Color(0xFF151719),
    surface: Color(0xFF222629),
    primary: Color(0xFFB8F56A),
    secondary: Color(0xFFFF8064),
    accent: Color(0xFFA7C7FF),
    highlight: Color(0xFFFFD84D),
    text: Color(0xFFF7F4EA),
    border: Color(0xFFF7F4EA),
    shadow: Color(0xFFB8F56A),
    muted: Color(0xFFC2BFB6),
  );

  static NeoPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class NeoTheme {
  static ThemeData light() => _build(NeoPalette.light, Brightness.light);
  static ThemeData dark() => _build(NeoPalette.dark, Brightness.dark);

  static ThemeData _build(NeoPalette palette, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: palette.primary, brightness: brightness)
            .copyWith(
      primary: palette.primary,
      secondary: palette.secondary,
      surface: palette.surface,
      onPrimary: const Color(0xFF171717),
      onSurface: palette.text,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: palette.border, width: 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
        titleTextStyle: TextStyle(
            color: palette.text, fontSize: 19, fontWeight: FontWeight.w900),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            color: palette.text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05),
        headlineSmall: TextStyle(
            color: palette.text, fontSize: 23, fontWeight: FontWeight.w900),
        titleLarge: TextStyle(
            color: palette.text, fontSize: 20, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(
            color: palette.text, fontSize: 16, fontWeight: FontWeight.w800),
        bodyLarge: TextStyle(
            color: palette.text, fontSize: 15, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(
            color: palette.text, fontSize: 13, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(
            color: palette.text, fontSize: 13, fontWeight: FontWeight.w900),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: BorderSide(color: palette.secondary, width: 2.5)),
        errorBorder: border.copyWith(
            borderSide: const BorderSide(color: Color(0xFFC62828), width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: const Color(0xFF171717),
          elevation: 0,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: palette.border, width: 2)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(44, 44),
          side: BorderSide(color: palette.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      dividerTheme: DividerThemeData(
          color: palette.border.withValues(alpha: .25), thickness: 1),
    );
  }
}
