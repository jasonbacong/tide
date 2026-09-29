import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late CheckInRepository repo;

  setUp(() {
    db = testDb();
    repo = CheckInRepository(db, FakeClock(DateTime(2026, 9, 28, 9)));
  });
  tearDown(() => db.close());

  test('saving parts of a day keeps one row per date', () async {
    await repo.saveIntention('2026-09-28', '  Be gentle ');
    await repo.saveMood('2026-09-28', 4);
    await repo.saveReflection('2026-09-28', 'A quiet, good day.');
    final rows = await db.select(db.checkIns).get();
    expect(rows, hasLength(1));
    final day = await repo.watchDay('2026-09-28').first;
    expect(day!.intention, 'Be gentle');
    expect(day.mood, 4);
    expect(day.reflection, 'A quiet, good day.');
  });

  test('blank text is stored as null and an emptied day leaves the journal', () async {
    await repo.saveIntention('2026-09-28', 'Walk');
    expect(await repo.watchEntries().first, hasLength(1));
    await repo.saveIntention('2026-09-28', '   ');
    final day = await repo.watchDay('2026-09-28').first;
    expect(day!.intention, isNull);
    expect(day.isEmpty, isTrue);
    expect(await repo.watchEntries().first, isEmpty);
  });

  test('mood accepts 1–5 or null only', () async {
    await repo.saveMood('2026-09-28', 5);
    await repo.saveMood('2026-09-28', null);
    expect((await repo.watchDay('2026-09-28').first)!.mood, isNull);
    expect(() => repo.saveMood('2026-09-28', 0), throwsArgumentError);
    expect(() => repo.saveMood('2026-09-28', 6), throwsArgumentError);
  });

  test('entries are newest first', () async {
    await repo.saveReflection('2026-09-20', 'older');
    await repo.saveReflection('2026-09-27', 'newer');
    expect((await repo.watchEntries().first).map((c) => c.date), ['2026-09-27', '2026-09-20']);
  });

  test('watchMonth maps days to moods within the month only', () async {
    await repo.saveMood('2026-08-31', 2);
    await repo.saveMood('2026-09-01', 3);
    await repo.saveReflection('2026-09-15', 'no mood');
    expect(await repo.watchMonth(2026, 9).first, {'2026-09-01': 3, '2026-09-15': null});
  });

  test('reflectionsBetween is inclusive and skips blanks', () async {
    await repo.saveReflection('2026-08-29', 'a month ago');
    await repo.saveReflection('2026-08-30', ' ');
    await repo.saveIntention('2026-08-31', 'intention only');
    expect(await repo.reflectionsBetween('2026-08-29', '2026-08-31'), {'2026-08-29': 'a month ago'});
  });
}
