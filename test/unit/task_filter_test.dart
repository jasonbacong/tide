import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_filter.dart';

import '../support/fake_clock.dart';

Task _t(String title, {Energy? energy, int? minutes}) => Task(
    id: title, title: title, createdAt: DateTime(2026), sortOrder: 0, energy: energy, minutes: minutes);

void main() {
  final tasks = [
    _t('low15', energy: Energy.low, minutes: 15),
    _t('high60', energy: Energy.high, minutes: 60),
    _t('low30', energy: Energy.low, minutes: 30),
    _t('plain'),
  ];

  List<String> titles(TaskFilter f) => filterTasks(tasks, f).map((t) => t.title).toList();

  test('empty filter shows everything', () {
    expect(titles(const TaskFilter()), ['low15', 'high60', 'low30', 'plain']);
  });

  test('energy filter', () {
    expect(titles(const TaskFilter(energy: Energy.low)), ['low15', 'low30']);
  });

  test('time filter is inclusive and hides untagged', () {
    expect(titles(const TaskFilter(maxMinutes: 15)), ['low15']);
    expect(titles(const TaskFilter(maxMinutes: 30)), ['low15', 'low30']);
  });

  test('energy and time narrow together', () {
    expect(titles(const TaskFilter(energy: Energy.low, maxMinutes: 15)), ['low15']);
    expect(titles(const TaskFilter(energy: Energy.high, maxMinutes: 15)), isEmpty);
  });

  test('toggling the selected chip clears it, and the filter resets the next day', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 20));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(container.dispose);
    final notifier = container.read(taskFilterProvider.notifier);

    notifier.toggleEnergy(Energy.low);
    notifier.toggleMaxMinutes(15);
    expect(container.read(taskFilterProvider).energy, Energy.low);
    notifier.toggleEnergy(Energy.low);
    expect(container.read(taskFilterProvider).energy, isNull);
    expect(container.read(taskFilterProvider).maxMinutes, 15);

    clock.set(DateTime(2026, 9, 29, 7));
    container.read(nowProvider.notifier).refresh();
    expect(container.read(taskFilterProvider).isEmpty, isTrue);
  });
}
