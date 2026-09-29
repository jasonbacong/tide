import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late GoalRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = GoalRepository(db, clock);
  });
  tearDown(() => db.close());

  test('create trims and starts active with no ring', () async {
    final g = await repo.create(title: ' Read 12 books ', why: 'Joy', targetSeason: 'by December');
    expect(g!.title, 'Read 12 books');
    expect(g.isActive, isTrue);
    final active = await repo.watchActive().first;
    expect(active.single.progress, isNull);
    expect(await repo.create(title: '  '), isNull);
  });

  test('a sixth active goal is refused', () async {
    for (var i = 0; i < 5; i++) {
      await repo.create(title: 'g$i');
    }
    expect(() => repo.create(title: 'sixth'), throwsA(isA<GoalLimitReached>()));
  });

  test('progress follows milestones and disappears when they are all removed', () async {
    final g = (await repo.create(title: 'Run 10k'))!;
    final a = (await repo.addMilestone(g.id, '3k'))!;
    await repo.addMilestone(g.id, '5k');
    await repo.toggleMilestone(a.id);
    expect((await repo.watchActive().first).single.progress, 0.5);

    for (final m in await repo.watchMilestones(g.id).first) {
      await repo.deleteMilestone(m.id);
    }
    expect((await repo.watchActive().first).single.progress, isNull);
  });

  test('achieved and let-go goals move to past, newest first, and free a slot', () async {
    final a = (await repo.create(title: 'a'))!;
    final b = (await repo.create(title: 'b'))!;
    await repo.markAchieved(a.id);
    clock.advance(const Duration(days: 1));
    await repo.letGo(b.id);
    expect(await repo.watchActive().first, isEmpty);
    final past = await repo.watchPast().first;
    expect(past.map((p) => p.goal.title), ['b', 'a']);
    expect(past.first.goal.status, GoalStatus.letGo);
    expect(past.last.goal.completedAt, isNotNull);
  });

  test('delete clears links but keeps tasks and habits', () async {
    final g = (await repo.create(title: 'Health'))!;
    final tasks = TaskRepository(db, clock);
    final habits = HabitRepository(db, clock);
    await tasks.add(title: 'Book check-up', date: '2026-09-28', goalId: g.id);
    await habits.add(name: 'Walk', icon: 'walk', goalId: g.id);
    await repo.addMilestone(g.id, 'First visit');

    await repo.delete(g.id);

    expect(await repo.watchGoal(g.id).first, isNull);
    expect(await repo.watchTitles().first, isEmpty);
    expect((await db.select(db.tasks).getSingle()).goalId, isNull);
    expect((await db.select(db.habits).getSingle()).goalId, isNull);
  });

  test('titles include past goals', () async {
    final g = (await repo.create(title: 'Learn Maltese'))!;
    await repo.markAchieved(g.id);
    expect(await repo.watchTitles().first, {g.id: 'Learn Maltese'});
  });

  test('milestones reorder and restore', () async {
    final g = (await repo.create(title: 'Trip'))!;
    final a = (await repo.addMilestone(g.id, 'a'))!;
    final b = (await repo.addMilestone(g.id, 'b'))!;
    await repo.reorderMilestones([b.id, a.id]);
    expect((await repo.watchMilestones(g.id).first).map((m) => m.title), ['b', 'a']);
    await repo.deleteMilestone(a.id);
    await repo.restoreMilestone(a.id);
    expect(await repo.watchMilestones(g.id).first, hasLength(2));
  });
}
