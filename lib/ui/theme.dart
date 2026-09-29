import 'package:flutter/material.dart';

import 'day_period.dart';
import 'tide_colors.dart';
import 'typography.dart';

ThemeData buildTheme(Brightness brightness, PartOfDay period) {
  final base = brightness == Brightness.light ? TideColors.light : TideColors.dark;
  final colors = base.copyWith(
    background: tintedBackground(base.background, period, brightness),
  );
  final scheme = ColorScheme.fromSeed(seedColor: colors.accent, brightness: brightness).copyWith(
    primary: colors.accent,
    onPrimary: Colors.white,
    secondary: colors.warm,
    surface: colors.background,
    onSurface: colors.ink,
  );
  final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    fontFamily: TideType.sans,
    extensions: [colors],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.card,
      indicatorColor: colors.soft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.ink,
      contentTextStyle: TextStyle(color: colors.background, fontFamily: TideType.sans),
      actionTextColor: colors.accent,
      elevation: 0,
      shape: rounded14,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.background,
      hintStyle: TextStyle(color: colors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: rounded14,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.background,
      selectedColor: colors.accent.withValues(alpha: 0.28),
      checkmarkColor: colors.ink,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(color: colors.ink, fontFamily: TideType.sans, fontSize: 13),
    ),
  );
}
