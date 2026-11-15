import 'package:flutter/material.dart';

/// Light-only neobrutalist palette. [muted] is a readable ink tone; [mutedSurface]
/// is the warm neutral used for backgrounds and separators.
class NeoPalette {
  const NeoPalette({required this.background, required this.surface, required this.primary,
    required this.secondary, required this.accent, required this.highlight,
    required this.text, required this.border, required this.shadow, required this.muted,
    required this.mutedSurface});
  final Color background, surface, primary, secondary, accent, highlight;
  final Color text, border, shadow, muted, mutedSurface;

  static const light = NeoPalette(
    background: Color(0xFFFFFDF5), surface: Color(0xFFFFFFFF),
    primary: Color(0xFFFFE66D), secondary: Color(0xFFFF90E8),
    accent: Color(0xFFA9C7FF), highlight: Color(0xFFB8F28B),
    text: Color(0xFF171717), border: Color(0xFF171717),
    shadow: Color(0xFF171717), muted: Color(0xFF605F58),
    mutedSurface: Color(0xFFE9E5D8),
  );
  static NeoPalette of(BuildContext context) => light;
}

class NeoTheme {
  static ThemeData light() {
    const p = NeoPalette.light;
    const ink = Color(0xFF171717);
    final scheme = ColorScheme.fromSeed(seedColor: p.primary, brightness: Brightness.light)
        .copyWith(primary: p.primary, secondary: p.secondary, surface: p.surface,
          onPrimary: ink, onSecondary: ink, onSurface: ink);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: p.border, width: 2),
    );
    const display = 'SpaceGrotesk';
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(backgroundColor: p.background, foregroundColor: ink,
        elevation: 0, scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(fontFamily: display, color: ink, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.5)),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: display, color: ink, fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -2, height: 1),
        headlineLarge: TextStyle(fontFamily: display, color: ink, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.5, height: 1.02),
        headlineSmall: TextStyle(fontFamily: display, color: ink, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -.8),
        titleLarge: TextStyle(fontFamily: display, color: ink, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.4),
        titleMedium: TextStyle(fontFamily: display, color: ink, fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
        bodyMedium: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
        labelLarge: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: p.surface,
        border: border, enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: p.border, width: 2)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: p.primary, foregroundColor: ink, elevation: 0,
        minimumSize: const Size(48, 48), textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: p.border, width: 2)))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: ink, minimumSize: const Size(48, 48),
        side: BorderSide(color: p.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700))),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide(color: p.border, width: 2),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.primary : p.surface),
        checkColor: WidgetStatePropertyAll(ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.primary : p.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.highlight : p.mutedSurface),
        trackOutlineColor: WidgetStatePropertyAll(p.border),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
      ),
      chipTheme: ChipThemeData(backgroundColor: p.surface, selectedColor: p.primary,
        side: BorderSide(color: p.border, width: 2), shape: const StadiumBorder()),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12)), side: BorderSide(color: ink, width: 2))),
      dialogTheme: DialogThemeData(backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: ink, width: 2))),
      dividerTheme: DividerThemeData(color: p.mutedSurface, thickness: 1),
      snackBarTheme: SnackBarThemeData(backgroundColor: ink, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}
