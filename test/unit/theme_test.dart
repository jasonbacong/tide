import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/tide_colors.dart';

void main() {
  test('light theme uses Sand and sea light tokens', () {
    final theme = buildTheme(Brightness.light, PartOfDay.afternoon);
    final c = theme.extension<TideColors>()!;
    expect(c.accent, const Color(0xFF6FA3A0));
    expect(c.card, const Color(0xFFFFFFFF));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF6EFE6));
  });

  test('dark theme uses Sand and sea dark tokens', () {
    final theme = buildTheme(Brightness.dark, PartOfDay.afternoon);
    final c = theme.extension<TideColors>()!;
    expect(c.accent, const Color(0xFF7FB5B1));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF1F1C19));
  });

  test('evening tints the background but not the cards', () {
    final theme = buildTheme(Brightness.light, PartOfDay.evening);
    expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFF6EFE6)));
    expect(theme.extension<TideColors>()!.card, const Color(0xFFFFFFFF));
    expect(theme.extension<TideColors>()!.background, theme.scaffoldBackgroundColor);
  });

  test('body text uses Inter', () {
    final theme = buildTheme(Brightness.light, PartOfDay.morning);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('mood scale has five colours', () {
    expect(TideColors.mood, hasLength(5));
  });
}
