import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/habit_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late HabitRepository repo;

  setUp(() {
    db = testDb();
    repo = HabitRepository(db, FakeClock(DateTime(2026, 9, 28, 9)));
  });
  tearDown(() => db.close());

  Future<Map<String, int>> counts(String day) async =>
      {for (final h in await repo.watchDay(day).first) h.habit.name: h.count};

  test('add trims, clamps the target and rejects blank names', () async {
    final h = await repo.add(name: '  Water ', icon: 'water', dailyTarget: 99);
    expect(h!.name, 'Water');
    expect(h.dailyTarget, 20);
    expect(await repo.add(name: ' ', icon: 'water'), isNull);
  });

  test('a new day starts at zero', () async {
    final h = await repo.add(name: 'Read', icon: 'book');
    await repo.tap(h!.id, '2026-09-28');
    expect(await counts('2026-09-28'), {'Read': 1});
    expect(await counts('2026-09-29'), {'Read': 0});
  });

  test('tap counts up to the target, then resets to zero', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 3);
    expect(await repo.tap(h!.id, '2026-09-28'), 1);
    expect(await repo.tap(h.id, '2026-09-28'), 2);
    expect(await repo.tap(h.id, '2026-09-28'), 3);
    final today = (await repo.watchDay('2026-09-28').first).single;
    expect(today.done, isTrue);
    expect(await repo.tap(h.id, '2026-09-28'), 0);
  });

  test('lowering the target keeps it done and never shows more than the target', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 8);
    for (var i = 0; i < 8; i++) {
      await repo.tap(h!.id, '2026-09-28');
    }
    await repo.update(h!.id, name: 'Water', icon: 'water', dailyTarget: 4);
    final today = (await repo.watchDay('2026-09-28').first).single;
    expect(today.done, isTrue);
    expect(today.shown, 4);
    expect(await repo.tap(h.id, '2026-09-28'), 0);
  });

  test('archived habits disappear from the day but keep their history', () async {
    final h = await repo.add(name: 'Stretch', icon: 'yoga');
    await repo.tap(h!.id, '2026-09-27');
    await repo.archive(h.id);
    expect(await counts('2026-09-28'), isEmpty);
    expect(await repo.completedDays(h.id, from: '2026-09-01', to: '2026-09-28'), {'2026-09-27'});
  });

  test('completedDays only counts days that met the target', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 2);
    await repo.tap(h!.id, '2026-09-26');
    await repo.tap(h.id, '2026-09-26');
    await repo.tap(h.id, '2026-09-27');
    expect(await repo.completedDays(h.id, from: '2026-09-20', to: '2026-09-28'), {'2026-09-26'});
  });

  test('reorder and activeCount', () async {
    final a = await repo.add(name: 'a', icon: 'book');
    final b = await repo.add(name: 'b', icon: 'book');
    await repo.reorder([b!.id, a!.id]);
    expect((await repo.watchActive().first).map((h) => h.name), ['b', 'a']);
    expect(await repo.activeCount(), 2);
  });

  test('watchForGoal lists active linked habits', () async {
    await repo.add(name: 'Walk', icon: 'walk', goalId: 'g1');
    final old = await repo.add(name: 'Old', icon: 'walk', goalId: 'g1');
    await repo.archive(old!.id);
    expect((await repo.watchForGoal('g1').first).map((h) => h.name), ['Walk']);
  });
}
