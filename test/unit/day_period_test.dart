import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';

void main() {
  group('periodFor boundaries', () {
    final cases = <(int, int, PartOfDay)>[
      (4, 59, PartOfDay.night),
      (5, 0, PartOfDay.morning),
      (11, 59, PartOfDay.morning),
      (12, 0, PartOfDay.afternoon),
      (16, 59, PartOfDay.afternoon),
      (17, 0, PartOfDay.evening),
      (21, 59, PartOfDay.evening),
      (22, 0, PartOfDay.night),
      (0, 0, PartOfDay.night),
    ];
    for (final (h, m, expected) in cases) {
      test('$h:$m is $expected', () {
        expect(periodFor(DateTime(2026, 9, 28, h, m)), expected);
      });
    }
  });

  group('tintedBackground', () {
    const base = Color(0xFFF6EFE6);

    test('afternoon leaves the background untouched', () {
      expect(tintedBackground(base, PartOfDay.afternoon, Brightness.light), base);
    });

    for (final period in [PartOfDay.morning, PartOfDay.evening, PartOfDay.night]) {
      for (final b in Brightness.values) {
        test('$period/$b shifts gently (<= 6% per channel)', () {
          final tinted = tintedBackground(base, period, b);
          expect(tinted, isNot(base));
          for (final (x, y) in [(tinted.r, base.r), (tinted.g, base.g), (tinted.b, base.b)]) {
            expect((x - y).abs(), lessThanOrEqualTo(0.06 + 1e-9));
          }
        });
      }
    }
  });
}
