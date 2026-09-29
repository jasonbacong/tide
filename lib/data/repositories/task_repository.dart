import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.sortOrder,
    this.energy,
    this.minutes,
    this.date,
    this.goalId,
    this.completedAt,
  });

  final String id;
  final String title;
  final Energy? energy;
  final int? minutes;
  final String? date;
  final String? goalId;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int sortOrder;

  bool get isDone => completedAt != null;
}

class TaskRepository {
  TaskRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  DateTime _now() => _clock.now().toUtc();

  Future<Task?> add({
    required String title,
    Energy? energy,
    int? minutes,
    String? date,
    String? goalId,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return null;
    final now = _now();
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          title: clean,
          energy: Value(energy),
          minutes: Value(minutes),
          date: Value(date),
          goalId: Value(goalId),
          sortOrder: Value(await _nextSortOrder()),
        ));
    return _toTask(await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> update(
    String id, {
    required String title,
    Energy? energy,
    int? minutes,
    String? date,
    String? goalId,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    await _write(
      id,
      TasksCompanion(
        title: Value(clean),
        energy: Value(energy),
        minutes: Value(minutes),
        date: Value(date),
        goalId: Value(goalId),
      ),
    );
  }

  Stream<List<Task>> watchTodayOpen(String today) {
    final q = _db.select(_db.tasks)
      ..where((t) =>
          t.deletedAt.isNull() & t.completedAt.isNull() & t.date.isSmallerOrEqualValue(today))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map(_toTasks);
  }

  Stream<List<Task>> watchDoneOn(String day) {
    final (start, end) = _utcBoundsOf(day);
    final q = _db.select(_db.tasks)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.completedAt.isBiggerOrEqualValue(start) &
          t.completedAt.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);
    return q.watch().map(_toTasks);
  }

  Stream<List<Task>> watchLater() {
    final q = _db.select(_db.tasks)
      ..where((t) => t.deletedAt.isNull() & t.completedAt.isNull() & t.date.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map(_toTasks);
  }

  Stream<List<Task>> watchOpenForGoal(String goalId) {
    final q = _db.select(_db.tasks)
      ..where((t) => t.deletedAt.isNull() & t.completedAt.isNull() & t.goalId.equals(goalId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map(_toTasks);
  }

  Future<void> complete(String id) => _write(id, TasksCompanion(completedAt: Value(_now())));

  Future<void> uncomplete(String id) => _write(id, const TasksCompanion(completedAt: Value(null)));

  Future<void> delete(String id) => _write(id, TasksCompanion(deletedAt: Value(_now())));

  Future<void> restore(String id) => _write(id, const TasksCompanion(deletedAt: Value(null)));

  Future<void> setDate(String id, String? date) => _write(id, TasksCompanion(date: Value(date)));

  Future<void> reorder(List<String> ids) => _db.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await _write(ids[i], TasksCompanion(sortOrder: Value(i)));
        }
      });

  Future<void> _write(String id, TasksCompanion changes) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  Future<int> _nextSortOrder() async {
    final max = _db.tasks.sortOrder.max();
    final row = await (_db.selectOnly(_db.tasks)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  /// UTC instants bounding the local calendar day [day] (`yyyy-MM-dd`).
  static (DateTime, DateTime) _utcBoundsOf(String day) {
    final start = DateTime.parse(day); // no offset → local midnight
    final end = DateTime(start.year, start.month, start.day + 1);
    return (start.toUtc(), end.toUtc());
  }

  static List<Task> _toTasks(List<TaskRow> rows) => rows.map(_toTask).toList();

  static Task _toTask(TaskRow r) => Task(
        id: r.id,
        title: r.title,
        energy: r.energy,
        minutes: r.minutes,
        date: r.date,
        goalId: r.goalId,
        completedAt: r.completedAt?.toLocal(),
        createdAt: r.createdAt.toLocal(),
        sortOrder: r.sortOrder,
      );
}
