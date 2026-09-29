import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = TaskRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<List<String>> open(String day) async =>
      (await repo.watchTodayOpen(day).first).map((t) => t.title).toList();
  Future<List<String>> done(String day) async =>
      (await repo.watchDoneOn(day).first).map((t) => t.title).toList();

  test('add trims and stores the optional tags', () async {
    final t = await repo.add(
        title: '  Call the dentist ', energy: Energy.low, minutes: 15, date: '2026-09-28');
    expect(t!.title, 'Call the dentist');
    expect(t.energy, Energy.low);
    expect(t.minutes, 15);
    expect(t.isDone, isFalse);
  });

  test('blank titles save nothing', () async {
    expect(await repo.add(title: '   '), isNull);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('today shows today and earlier, never future or undated', () async {
    await repo.add(title: 'yesterday', date: '2026-09-27');
    await repo.add(title: 'today', date: '2026-09-28');
    await repo.add(title: 'tomorrow', date: '2026-09-29');
    await repo.add(title: 'later');
    expect(await open('2026-09-28'), ['yesterday', 'today']);
  });

  test('completing moves a task from open to done for that day only', () async {
    final t = await repo.add(title: 'Water plants', date: '2026-09-28');
    clock.set(DateTime(2026, 9, 28, 23, 59));
    await repo.complete(t!.id);
    expect(await open('2026-09-28'), isEmpty);
    expect(await done('2026-09-28'), ['Water plants']);
    expect(await done('2026-09-29'), isEmpty);
    expect(await open('2026-09-29'), isEmpty);
  });

  test('uncomplete puts it back', () async {
    final t = await repo.add(title: 'Stretch', date: '2026-09-28');
    await repo.complete(t!.id);
    await repo.uncomplete(t.id);
    expect(await open('2026-09-28'), ['Stretch']);
    expect(await done('2026-09-28'), isEmpty);
  });

  test('later lists undated open tasks and setDate moves them to today', () async {
    final t = await repo.add(title: 'Sort photos');
    expect((await repo.watchLater().first).map((t) => t.title), ['Sort photos']);
    await repo.setDate(t!.id, '2026-09-28');
    expect(await repo.watchLater().first, isEmpty);
    expect(await open('2026-09-28'), ['Sort photos']);
  });

  test('delete hides and restore brings back', () async {
    final t = await repo.add(title: 'Pay rent', date: '2026-09-28');
    await repo.delete(t!.id);
    expect(await open('2026-09-28'), isEmpty);
    await repo.restore(t.id);
    expect(await open('2026-09-28'), ['Pay rent']);
  });

  test('new tasks go to the bottom and reorder rewrites the order', () async {
    final a = await repo.add(title: 'a', date: '2026-09-28');
    final b = await repo.add(title: 'b', date: '2026-09-28');
    final c = await repo.add(title: 'c', date: '2026-09-28');
    expect(await open('2026-09-28'), ['a', 'b', 'c']);
    await repo.reorder([c!.id, a!.id, b!.id]);
    expect(await open('2026-09-28'), ['c', 'a', 'b']);
  });

  test('update changes title, tags and date', () async {
    final t = await repo.add(title: 'Draft', date: '2026-09-28');
    await repo.update(t!.id, title: 'Final', energy: Energy.high, minutes: 60, date: null);
    expect(await open('2026-09-28'), isEmpty);
    final later = (await repo.watchLater().first).single;
    expect(later.title, 'Final');
    expect(later.energy, Energy.high);
    expect(later.minutes, 60);
  });
}
