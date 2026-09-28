import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/clock.dart';

import '../support/fake_clock.dart';

void main() {
  test('dateKey pads month and day', () {
    expect(dateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('dateKey uses the local calendar date', () {
    expect(dateKey(DateTime(2026, 12, 31, 0, 0)), '2026-12-31');
  });

  test('FakeClock advances', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 30));
    clock.advance(const Duration(hours: 1));
    expect(dateKey(clock.now()), '2026-09-29');
  });

  test('SystemClock returns a current time', () {
    final before = DateTime.now();
    final now = const SystemClock().now();
    expect(now.isBefore(before), isFalse);
  });
}
