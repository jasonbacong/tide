import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.dailyTarget,
    required this.sortOrder,
    this.goalId,
  });

  final String id;
  final String name;
  final String icon;
  final int dailyTarget;
  final String? goalId;
  final int sortOrder;
}

class HabitToday {
  const HabitToday({required this.habit, required this.count});

  final Habit habit;
  final int count;

  bool get done => count >= habit.dailyTarget;

  /// Count as shown to the user: never more than the target.
  int get shown => math.min(count, habit.dailyTarget);
}

class HabitRepository {
  HabitRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static const maxTarget = 20;

  DateTime _now() => _clock.now().toUtc();

  int _clampTarget(int t) => t.clamp(1, maxTarget);

  Stream<List<HabitToday>> watchDay(String day) {
    final h = _db.habits;
    final t = _db.habitTicks;
    final q = _db.select(h).join([
      leftOuterJoin(t, t.habitId.equalsExp(h.id) & t.date.equals(day)),
    ])
      ..where(h.archived.equals(false) & h.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(h.sortOrder), OrderingTerm.asc(h.createdAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            HabitToday(habit: _toHabit(r.readTable(h)), count: r.readTableOrNull(t)?.count ?? 0),
        ]);
  }

  Stream<List<Habit>> watchActive() {
    final q = _db.select(_db.habits)
      ..where((h) => h.archived.equals(false) & h.deletedAt.isNull())
      ..orderBy([(h) => OrderingTerm.asc(h.sortOrder), (h) => OrderingTerm.asc(h.createdAt)]);
    return q.watch().map((rows) => rows.map(_toHabit).toList());
  }

  Stream<List<Habit>> watchForGoal(String goalId) {
    final q = _db.select(_db.habits)
      ..where((h) => h.archived.equals(false) & h.deletedAt.isNull() & h.goalId.equals(goalId))
      ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]);
    return q.watch().map((rows) => rows.map(_toHabit).toList());
  }

  Future<int> activeCount() async {
    final count = _db.habits.id.count();
    final row = await (_db.selectOnly(_db.habits)
          ..addColumns([count])
          ..where(_db.habits.archived.equals(false) & _db.habits.deletedAt.isNull()))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<Habit?> add({
    required String name,
    required String icon,
    int dailyTarget = 1,
    String? goalId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final now = _now();
    final id = _uuid.v4();
    final max = _db.habits.sortOrder.max();
    final next =
        ((await (_db.selectOnly(_db.habits)..addColumns([max])).getSingle()).read(max) ?? -1) + 1;
    await _db.into(_db.habits).insert(HabitsCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          name: clean,
          icon: icon,
          dailyTarget: Value(_clampTarget(dailyTarget)),
          goalId: Value(goalId),
          sortOrder: Value(next),
        ));
    return _toHabit(await (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingle());
  }

  Future<void> update(
    String id, {
    required String name,
    required String icon,
    required int dailyTarget,
    String? goalId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _write(
        id,
        HabitsCompanion(
          name: Value(clean),
          icon: Value(icon),
          dailyTarget: Value(_clampTarget(dailyTarget)),
          goalId: Value(goalId),
        ));
  }

  Future<void> archive(String id) => _write(id, const HabitsCompanion(archived: Value(true)));

  Future<void> reorder(List<String> ids) => _db.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await _write(ids[i], HabitsCompanion(sortOrder: Value(i)));
        }
      });

  /// One tap: +1 up to the target; a tap on a done habit resets today to 0.
  Future<int> tap(String habitId, String day) => _db.transaction(() async {
        final habit =
            await (_db.select(_db.habits)..where((h) => h.id.equals(habitId))).getSingle();
        final tick = await (_db.select(_db.habitTicks)
              ..where((t) => t.habitId.equals(habitId) & t.date.equals(day)))
            .getSingleOrNull();
        final now = _now();
        if (tick == null) {
          await _db.into(_db.habitTicks).insert(HabitTicksCompanion.insert(
                id: _uuid.v4(),
                createdAt: now,
                updatedAt: now,
                habitId: habitId,
                date: day,
                count: 1,
              ));
          return 1;
        }
        final next = tick.count >= habit.dailyTarget ? 0 : tick.count + 1;
        await (_db.update(_db.habitTicks)..where((t) => t.id.equals(tick.id)))
            .write(HabitTicksCompanion(count: Value(next), updatedAt: Value(now)));
        return next;
      });

  /// Dates in [from, to] (inclusive, `yyyy-MM-dd`) on which the habit met its current target.
  Future<Set<String>> completedDays(String habitId,
      {required String from, required String to}) async {
    final habit =
        await (_db.select(_db.habits)..where((h) => h.id.equals(habitId))).getSingle();
    final ticks = await (_db.select(_db.habitTicks)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to)))
        .get();
    return {for (final t in ticks) if (t.count >= habit.dailyTarget) t.date};
  }

  Future<void> _write(String id, HabitsCompanion changes) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  static Habit _toHabit(HabitRow r) => Habit(
        id: r.id,
        name: r.name,
        icon: r.icon,
        dailyTarget: r.dailyTarget,
        goalId: r.goalId,
        sortOrder: r.sortOrder,
      );
}
