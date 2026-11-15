import 'package:flutter/material.dart';

import '../ml/risk_label.dart';

/// Colours taken from the research plan's mock-ups (Figures 1-18).
abstract final class Palette {
  static const primary = Color(0xFF0066E7);
  static const royal = Color(0xFF0545B5);
  static const heading = Color(0xFF0341AB);
  static const navy = Color(0xFF0B1E5B);
  static const brandBlue = Color(0xFF3F7BD0);
  static const info = Color(0xFFC5D2EA);
  static const panel = Color(0xFFF5F8FE);
  static const tipIcon = Color(0xFF3E6DAB);
  static const muted = Color(0xFF5B6B86);

  static const darkTop = Color(0xFF000814);
  static const darkMiddle = Color(0xFF011537);
  static const darkBottom = Color(0xFF001C5A);
  static const darkPage = Color(0xFF001D5B);
  static const darkCard = Color(0xFF021638);
  static const darkBorder = Color(0xFF8795A2);
  static const darkDrawer = Color(0xFF3C69A6);

  static const lightTop = Color(0xFFF5F8FE);
  static const lightBottom = Color(0xFFAFD3FE);
  static const lightField = Color(0xFFDCE6F6);
  static const lightDrawer = Color(0xFF8CB4E8);
}

/// Colours, icon and wording style for one result category.
class RiskStyle {
  const RiskStyle(this.background, this.foreground, this.icon);

  factory RiskStyle.of(RiskLabel label) => switch (label) {
    RiskLabel.safe => const RiskStyle(
      Color(0xFFE7F2E9),
      Color(0xFF2F8F2A),
      Icons.gpp_good,
    ),
    RiskLabel.suspicious => const RiskStyle(
      Color(0xFFFFF6E6),
      Color(0xFFE29719),
      Icons.warning_rounded,
    ),
    RiskLabel.highRisk => const RiskStyle(
      Color(0xFFFDE5E5),
      Color(0xFFC62F3B),
      Icons.gpp_bad,
    ),
  };

  final Color background;
  final Color foreground;
  final IconData icon;
}

const String fontFamily = 'Poppins';

ThemeData buildTheme({required bool dark}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xFF4C8DF0) : Palette.royal,
    surface: dark ? Palette.darkCard : Colors.white,
  );
  final onBackground = dark ? Colors.white : Palette.navy;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: onBackground,
      displayColor: onBackground,
      fontFamily: fontFamily,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? Palette.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Text on the page background (outside the light panels).
  Color get onPage => isDark ? Colors.white : Palette.navy;
}
