import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/day_period.dart';
import 'clock.dart';
import 'db/app_database.dart';
import 'repositories/capture_repository.dart';
import 'repositories/check_in_repository.dart';
import 'repositories/goal_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/task_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Current time, re-read at every minute boundary (so midnight is caught on the dot)
/// and on app resume (see TideApp).
class NowNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    ref.onDispose(() => _timer?.cancel());
    _scheduleNextMinute(clock);
    return clock.now();
  }

  void _scheduleNextMinute(Clock clock) {
    _timer?.cancel();
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _timer = Timer(next.difference(now), () {
      state = clock.now();
      _scheduleNextMinute(clock);
    });
  }

  void refresh() => state = ref.read(clockProvider).now();
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

final dayPeriodProvider = Provider<PartOfDay>((ref) => periodFor(ref.watch(nowProvider)));

/// Today's local date key. Everything per-day watches this, so it rolls over at midnight.
final todayKeyProvider = Provider<String>((ref) => dateKey(ref.watch(nowProvider)));

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => CheckInRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);
