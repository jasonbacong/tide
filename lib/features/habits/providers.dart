import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';

final todayHabitsProvider = StreamProvider<List<HabitToday>>((ref) =>
    ref.watch(habitRepositoryProvider).watchDay(ref.watch(todayKeyProvider)));

final habitHistoryProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, habitId) async {
  final today = ref.watch(todayKeyProvider);
  final from = DateTime.parse(today).subtract(const Duration(days: 34));
  return ref.watch(habitRepositoryProvider).completedDays(
        habitId,
        from: dateKey(from),
        to: today,
      );
});
