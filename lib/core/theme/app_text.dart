import 'package:flutter/material.dart';

/// The app's type, matching the web app: Space Grotesk for headings and the
/// brand, Manrope for text, JetBrains Mono for amounts and readings. Sizes are
/// a little larger than the web's, for reading on a phone.
///
/// Every style leaves colour out; callers add it from `AppColors`, so the
/// same style works in light and dark mode.
abstract final class AppText {
  static const display = 'SpaceGrotesk';
  static const body = 'Manrope';
  static const mono = 'JetBrainsMono';

  /// The big heading of a screen: "Water readings".
  static const headline = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// A heading inside a screen, or a card's title: "House A4".
  static const title = TextStyle(
    fontFamily: display,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// A row's main text, bold: a tenant's name.
  static const label = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  /// Ordinary text.
  static const text = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Secondary text under a label: "One bedroom · Floor 2".
  static const small = TextStyle(
    fontFamily: body,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// The small capital label above a section: "THIS MONTH".
  static const eyebrow = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    height: 1.3,
  );

  /// Amounts and meter readings: "KES 12,500", "168 → 180".
  static const amount = TextStyle(
    fontFamily: mono,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A big figure on a summary card: "18 of 24".
  static const figure = TextStyle(
    fontFamily: mono,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
