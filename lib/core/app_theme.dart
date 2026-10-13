import 'package:flutter/material.dart';

/// The app's colours, the same ones the web app uses in light and dark mode.
///
/// Screens take colours from here (`AppColors.of(context)`) and never write
/// a colour value themselves, so both modes stay correct.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineSoft,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
  });

  static const light = AppColors(
    bg: Color(0xFFF7F4EF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF201C18),
    inkSoft: Color(0xFF6F675E),
    inkFaint: Color(0xFFA39B8D),
    line: Color(0xFFE7E0D5),
    lineSoft: Color(0xFFF0EAE0),
    accent: Color(0xFFC1440E),
    accentInk: Color(0xFFC1440E),
    accentSoft: Color(0xFFFBE7DA),
    success: Color(0xFF2E7D4F),
    successSoft: Color(0xFFE3F1E8),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE4E2),
    warning: Color(0xFFB8790E),
    warningSoft: Color(0xFFFBF0DA),
    info: Color(0xFF3C5C82),
    infoSoft: Color(0xFFE6EDF4),
  );

  static const dark = AppColors(
    bg: Color(0xFF14110E),
    surface: Color(0xFF1F1B16),
    ink: Color(0xFFF1EBE0),
    inkSoft: Color(0xFFB9B0A2),
    inkFaint: Color(0xFF8D8477),
    line: Color(0xFF352E26),
    lineSoft: Color(0xFF2A241E),
    accent: Color(0xFFC1440E),
    accentInk: Color(0xFFEE8650),
    accentSoft: Color(0xFF3B2215),
    success: Color(0xFF6CC495),
    successSoft: Color(0xFF17301F),
    danger: Color(0xFFF2837A),
    dangerSoft: Color(0xFF3A1B18),
    warning: Color(0xFFE3AE4C),
    warningSoft: Color(0xFF382B10),
    info: Color(0xFF94B5DE),
    infoSoft: Color(0xFF1B2A3B),
  );

  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color lineSoft;

  /// The orange used for filled buttons, with white text on it.
  final Color accent;

  /// The orange used for text and icons; lighter in dark mode so it stays readable.
  final Color accentInk;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    // The two modes switch at once; nothing is blended between them.
    return other is AppColors && t >= 0.5 ? other : this;
  }
}

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final radius = BorderRadius.circular(8);

  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    extensions: [colors],
    scaffoldBackgroundColor: colors.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: Colors.white,
      secondary: colors.accentInk,
      onSecondary: Colors.white,
      error: colors.danger,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.ink,
      outline: colors.line,
      outlineVariant: colors.lineSoft,
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: colors.line)),
      titleTextStyle: TextStyle(color: colors.ink, fontSize: 17, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: colors.inkFaint),
      border: border(colors.line),
      enabledBorder: border(colors.line),
      focusedBorder: border(colors.accent, 1.5),
      errorBorder: border(colors.danger),
      focusedErrorBorder: border(colors.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        // Large enough to press with a thumb.
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        backgroundColor: colors.surface,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accentInk,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
  );
}
