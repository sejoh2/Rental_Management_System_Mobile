import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Spacing and shapes used across the app, as on the web: 8 px corners on
/// controls, 10 px on cards, thin borders and no shadows.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// The side margin of every screen.
  static const page = 16.0;

  static const controlRadius = 8.0;
  static const cardRadius = 10.0;

  /// The height of buttons and fields: large enough for a thumb.
  static const control = 50.0;
}

ThemeData buildTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  final radius = BorderRadius.circular(AppSpace.controlRadius);

  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  final textTheme = TextTheme(
    headlineMedium: AppText.headline.copyWith(color: colors.ink),
    titleLarge: AppText.title.copyWith(color: colors.ink),
    titleMedium: AppText.label.copyWith(color: colors.ink),
    titleSmall: AppText.label.copyWith(color: colors.ink, fontSize: 13),
    bodyLarge: AppText.text.copyWith(color: colors.ink),
    bodyMedium: AppText.text.copyWith(color: colors.ink),
    bodySmall: AppText.small.copyWith(color: colors.inkSoft),
    labelLarge: AppText.label.copyWith(color: colors.ink),
    labelMedium: AppText.small.copyWith(
      color: colors.inkSoft,
      fontWeight: FontWeight.w700,
    ),
    labelSmall: AppText.eyebrow.copyWith(color: colors.inkFaint),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: AppText.body,
    extensions: [colors],
    scaffoldBackgroundColor: colors.bg,
    textTheme: textTheme,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: AppColors.onAccent,
      secondary: colors.accentInk,
      onSecondary: AppColors.onAccent,
      error: colors.danger,
      onError: AppColors.onAccent,
      surface: colors.surface,
      onSurface: colors.ink,
      outline: colors.line,
      outlineVariant: colors.lineSoft,
      surfaceContainerHighest: colors.lineSoft,
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: colors.line)),
      titleTextStyle: AppText.title.copyWith(color: colors.ink, fontSize: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accentSoft,
      elevation: 0,
      height: 66,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.accentInk
              : colors.inkSoft,
          size: 23,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.small.copyWith(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? colors.accentInk
              : colors.inkSoft,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpace.cardRadius),
        side: BorderSide(color: colors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      labelStyle: AppText.text.copyWith(color: colors.inkSoft),
      floatingLabelStyle: AppText.small.copyWith(
        color: colors.accentInk,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: AppText.text.copyWith(color: colors.inkFaint),
      helperStyle: AppText.small.copyWith(color: colors.inkFaint, fontSize: 12),
      errorStyle: AppText.small.copyWith(color: colors.danger, fontSize: 12),
      helperMaxLines: 3,
      errorMaxLines: 3,
      border: border(colors.line),
      enabledBorder: border(colors.line),
      focusedBorder: border(colors.accent, 1.5),
      errorBorder: border(colors.danger),
      focusedErrorBorder: border(colors.danger, 1.5),
      disabledBorder: border(colors.lineSoft),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: colors.accent.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.onAccent.withValues(alpha: 0.85),
        minimumSize: const Size.fromHeight(AppSpace.control),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: AppText.label.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        backgroundColor: colors.surface,
        minimumSize: const Size.fromHeight(AppSpace.control),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: AppText.label.copyWith(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accentInk,
        textStyle: AppText.label,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.accentSoft,
      side: BorderSide(color: colors.line),
      labelStyle: AppText.small.copyWith(
        color: colors.ink,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.inkSoft,
      titleTextStyle: AppText.label.copyWith(color: colors.ink),
      subtitleTextStyle: AppText.small.copyWith(color: colors.inkSoft),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: colors.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpace.cardRadius),
      ),
      titleTextStyle: AppText.title.copyWith(color: colors.ink),
      contentTextStyle: AppText.text.copyWith(color: colors.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.ink,
      contentTextStyle: AppText.text.copyWith(color: colors.bg),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
  );
}
