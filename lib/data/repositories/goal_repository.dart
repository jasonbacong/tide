import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.status,
    required this.sortOrder,
    this.why,
    this.targetSeason,
    this.completedAt,
  });

  final String id;
  final String title;
  final String? why;
  final String? targetSeason;
  final GoalStatus status;
  final DateTime? completedAt;
  final int sortOrder;

  bool get isActive => status == GoalStatus.active;
}

class GoalWithProgress {
  const GoalWithProgress({required this.goal, required this.done, required this.total});

  final Goal goal;
  final int done;
  final int total;

  /// Null when there are no milestones: no ring is shown.
  double? get progress => total == 0 ? null : done / total;
}

class Milestone {
  const Milestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.done,
    required this.sortOrder,
  });

  final String id;
  final String goalId;
  final String title;
  final bool done;
  final int sortOrder;
}

class GoalLimitReached implements Exception {
  const GoalLimitReached();

  @override
  String toString() => 'You have 5 goals already. Finish or let one go first.';
}

class GoalRepository {
  GoalRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static const maxActive = 5;

  DateTime _now() => _clock.now().toUtc();

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Stream<List<GoalWithProgress>> _watch(String where, List<Variable<Object>> vars, String orderBy) {
    return _db
        .customSelect(
          'SELECT g.*, '
          '(SELECT COUNT(*) FROM milestones m WHERE m.goal_id = g.id AND m.deleted_at IS NULL) AS m_total, '
          '(SELECT COUNT(*) FROM milestones m WHERE m.goal_id = g.id AND m.deleted_at IS NULL AND m.done = 1) AS m_done '
          'FROM goals g WHERE g.deleted_at IS NULL AND $where ORDER BY $orderBy',
          variables: vars,
          readsFrom: {_db.goals, _db.milestones},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                GoalWithProgress(
                  goal: _toGoal(_db.goals.map(r.data)),
                  done: r.read<int>('m_done'),
                  total: r.read<int>('m_total'),
                ),
            ]);
  }

  Stream<List<GoalWithProgress>> watchActive() => _watch(
      'g.status = ?', [Variable.withString(GoalStatus.active.name)], 'g.sort_order, g.created_at');

  Stream<List<GoalWithProgress>> watchPast() => _watch(
        'g.status IN (?, ?)',
        [Variable.withString(GoalStatus.achieved.name), Variable.withString(GoalStatus.letGo.name)],
        'g.completed_at DESC',
      );

  Stream<Goal?> watchGoal(String id) =>
      (_db.select(_db.goals)..where((g) => g.id.equals(id) & g.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toGoal(r));

  Stream<Map<String, String>> watchTitles() =>
      (_db.select(_db.goals)..where((g) => g.deletedAt.isNull()))
          .watch()
          .map((rows) => {for (final r in rows) r.id: r.title});

  /// Direct count (not a stream) so it is safe inside create()'s transaction.
  Future<int> activeCount() async {
    final count = _db.goals.id.count();
    final row = await (_db.selectOnly(_db.goals)
          ..addColumns([count])
          ..where(_db.goals.status.equalsValue(GoalStatus.active) & _db.goals.deletedAt.isNull()))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<Goal?> create({required String title, String? why, String? targetSeason}) async {
    final clean = _clean(title);
    if (clean == null) return null;
    return _db.transaction(() async {
      if (await activeCount() >= maxActive) throw const GoalLimitReached();
      final now = _now();
      final id = _uuid.v4();
      final max = _db.goals.sortOrder.max();
      final next =
          ((await (_db.selectOnly(_db.goals)..addColumns([max])).getSingle()).read(max) ?? -1) + 1;
      await _db.into(_db.goals).insert(GoalsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            title: clean,
            why: Value(_clean(why)),
            targetSeason: Value(_clean(targetSeason)),
            status: GoalStatus.active,
            sortOrder: Value(next),
          ));
      return _toGoal(await (_db.select(_db.goals)..where((g) => g.id.equals(id))).getSingle());
    });
  }

  Future<void> update(String id, {required String title, String? why, String? targetSeason}) async {
    final clean = _clean(title);
    if (clean == null) return;
    await _writeGoal(
        id,
        GoalsCompanion(
          title: Value(clean),
          why: Value(_clean(why)),
          targetSeason: Value(_clean(targetSeason)),
        ));
  }

  Future<void> markAchieved(String id) => _writeGoal(
      id, GoalsCompanion(status: const Value(GoalStatus.achieved), completedAt: Value(_now())));

  Future<void> letGo(String id) => _writeGoal(
      id, GoalsCompanion(status: const Value(GoalStatus.letGo), completedAt: Value(_now())));

  Future<void> delete(String id) => _db.transaction(() async {
        final now = _now();
        await _writeGoal(id, GoalsCompanion(deletedAt: Value(now)));
        await (_db.update(_db.milestones)..where((m) => m.goalId.equals(id)))
            .write(MilestonesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
        await (_db.update(_db.tasks)..where((t) => t.goalId.equals(id)))
            .write(TasksCompanion(goalId: const Value(null), updatedAt: Value(now)));
        await (_db.update(_db.habits)..where((h) => h.goalId.equals(id)))
            .write(HabitsCompanion(goalId: const Value(null), updatedAt: Value(now)));
      });

  Stream<List<Milestone>> watchMilestones(String goalId) {
    final q = _db.select(_db.milestones)
      ..where((m) => m.goalId.equals(goalId) & m.deletedAt.isNull())
      ..orderBy([(m) => OrderingTerm.asc(m.sortOrder), (m) => OrderingTerm.asc(m.createdAt)]);
    return q.watch().map((rows) => rows.map(_toMilestone).toList());
  }

  Future<Milestone?> addMilestone(String goalId, String title) async {
    final clean = _clean(title);
    if (clean == null) return null;
    final now = _now();
    final id = _uuid.v4();
    final max = _db.milestones.sortOrder.max();
    final next = ((await (_db.selectOnly(_db.milestones)
                  ..addColumns([max])
                  ..where(_db.milestones.goalId.equals(goalId)))
                .getSingle())
            .read(max) ??
        -1) +
        1;
    await _db.into(_db.milestones).insert(MilestonesCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          goalId: goalId,
          title: clean,
          sortOrder: Value(next),
        ));
    return _toMilestone(
        await (_db.select(_db.milestones)..where((m) => m.id.equals(id))).getSingle());
  }

  Future<void> toggleMilestone(String id) => _db.transaction(() async {
        final m = await (_db.select(_db.milestones)..where((m) => m.id.equals(id))).getSingle();
        await _writeMilestone(id, MilestonesCompanion(done: Value(!m.done)));
      });

  Future<void> deleteMilestone(String id) =>
      _writeMilestone(id, MilestonesCompanion(deletedAt: Value(_now())));

  Future<void> restoreMilestone(String id) =>
      _writeMilestone(id, const MilestonesCompanion(deletedAt: Value(null)));

  Future<void> reorderMilestones(List<String> ids) => _db.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await _writeMilestone(ids[i], MilestonesCompanion(sortOrder: Value(i)));
        }
      });

  Future<void> _writeGoal(String id, GoalsCompanion changes) =>
      (_db.update(_db.goals)..where((g) => g.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  Future<void> _writeMilestone(String id, MilestonesCompanion changes) =>
      (_db.update(_db.milestones)..where((m) => m.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  static Goal _toGoal(GoalRow r) => Goal(
        id: r.id,
        title: r.title,
        why: r.why,
        targetSeason: r.targetSeason,
        status: r.status,
        completedAt: r.completedAt?.toLocal(),
        sortOrder: r.sortOrder,
      );

  static Milestone _toMilestone(MilestoneRow r) =>
      Milestone(id: r.id, goalId: r.goalId, title: r.title, done: r.done, sortOrder: r.sortOrder);
}
