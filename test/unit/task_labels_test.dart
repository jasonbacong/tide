import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_labels.dart';

Task _t({Energy? energy, int? minutes}) => Task(
    id: 'x', title: 'x', createdAt: DateTime(2026), sortOrder: 0, energy: energy, minutes: minutes);

void main() {
  test('labels', () {
    expect(energyLabel(Energy.medium), 'Medium');
    expect(minutesLabel(15), '15 min');
    expect(minutesLabel(60), '60+ min');
  });

  test('taskMeta joins what is set', () {
    expect(taskMeta(_t()), '');
    expect(taskMeta(_t(energy: Energy.low)), 'Low energy');
    expect(taskMeta(_t(energy: Energy.low, minutes: 15)), 'Low energy · 15 min');
    expect(taskMeta(_t(minutes: 60)), '60+ min');
  });
}
