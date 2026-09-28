import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/clock.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/ui/day_period.dart';

import '../support/fake_clock.dart';

void main() {
  test('refresh picks up a new day after midnight', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 59));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(container.dispose);

    expect(dateKey(container.read(nowProvider)), '2026-09-28');
    expect(container.read(dayPeriodProvider), PartOfDay.night);

    clock.set(DateTime(2026, 9, 29, 7));
    container.read(nowProvider.notifier).refresh();

    expect(dateKey(container.read(nowProvider)), '2026-09-29');
    expect(container.read(dayPeriodProvider), PartOfDay.morning);
  });
}
