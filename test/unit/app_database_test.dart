import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 28, 9);

  setUp(() => db = testDb());
  tearDown(() => db.close());

  test('creates the single settings row on first open', () async {
    final rows = await db.select(db.appSettings).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 1);
    expect(rows.single.name, '');
    expect(rows.single.themeMode, ThemePreference.system);
  });

  test('habit ticks are unique per habit and date', () async {
    HabitTicksCompanion tick(String id) => HabitTicksCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          habitId: 'h1',
          date: '2026-09-28',
          count: 1,
        );
    await db.into(db.habitTicks).insert(tick('a'));
    await expectLater(db.into(db.habitTicks).insert(tick('b')), throwsA(isA<Exception>()));
  });

  test('mood must be between 1 and 5', () async {
    CheckInsCompanion checkIn(String date, int mood) => CheckInsCompanion.insert(
          id: date,
          createdAt: now,
          updatedAt: now,
          date: date,
          mood: Value(mood),
        );
    await db.into(db.checkIns).insert(checkIn('2026-09-28', 5));
    await expectLater(
        db.into(db.checkIns).insert(checkIn('2026-09-29', 6)), throwsA(isA<Exception>()));
  });

  test('stores enums and keeps millisecond timestamps', () async {
    final at = DateTime(2026, 9, 28, 9, 0, 0, 123);
    await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'g1',
          createdAt: at,
          updatedAt: at,
          title: 'Read 12 books',
          status: GoalStatus.letGo,
        ));
    final row = await db.select(db.goals).getSingle();
    expect(row.status, GoalStatus.letGo);
    expect(row.createdAt.millisecond, 123);
  });
}
