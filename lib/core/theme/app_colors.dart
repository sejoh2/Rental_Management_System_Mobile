import 'package:flutter/material.dart';

/// The app's colours: the same light and dark sets as the web app
/// (`src/index.css` in the web project).
///
/// Screens take colours from here, `AppColors.of(context)`, and never write
/// a colour value themselves, so both modes always stay correct.
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
    required this.accentHover,
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
    accentHover: Color(0xFFA6390B),
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
    accentHover: Color(0xFFA6390B),
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

  /// The dark brand panel (landing, sign-in), the same in both modes.
  static const brandPanel = Color(0xFF1C1712);
  static const brandPanelSoft = Color(0xFF948B7C);
  static const brandEyebrow = Color(0xFFE8A87C);

  /// Filled buttons and the brand mark carry white text in both modes.
  static const onAccent = Color(0xFFFFFFFF);

  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color lineSoft;

  /// The orange of filled buttons, with white text on it.
  final Color accent;
  final Color accentHover;

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

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    // The two modes switch at once; nothing is blended between them.
    return other is AppColors && t >= 0.5 ? other : this;
  }
}
