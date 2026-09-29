import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';

class TaskFilter {
  const TaskFilter({this.energy, this.maxMinutes});

  final Energy? energy;
  final int? maxMinutes;

  bool get isEmpty => energy == null && maxMinutes == null;

  /// Untagged tasks never match an active filter.
  bool matches(Task t) {
    if (energy != null && t.energy != energy) return false;
    if (maxMinutes != null && (t.minutes == null || t.minutes! > maxMinutes!)) return false;
    return true;
  }
}

List<Task> filterTasks(List<Task> tasks, TaskFilter filter) =>
    filter.isEmpty ? tasks : tasks.where(filter.matches).toList();

/// Rebuilds (and so resets) whenever the day changes.
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() {
    ref.watch(todayKeyProvider);
    return const TaskFilter();
  }

  void toggleEnergy(Energy e) => state =
      TaskFilter(energy: state.energy == e ? null : e, maxMinutes: state.maxMinutes);

  void clear() => state = const TaskFilter();

  void toggleMaxMinutes(int m) => state =
      TaskFilter(energy: state.energy, maxMinutes: state.maxMinutes == m ? null : m);
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);
