import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/habits/habit_circle.dart';
import 'package:tide/features/habits/habits_card.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  HabitCircle circle(WidgetTester tester, Habit h) =>
      tester.widget<HabitCircle>(find.byKey(ValueKey('habit-${h.id}')));

  testWidgets('empty card invites a first habit', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text("Add a habit or two you'd like to keep."), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping a once-a-day habit completes it, tapping again undoes it', (tester) async {
    late Habit read;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      read = (await HabitRepository(db, clock).add(name: 'Read', icon: 'book'))!;
    });
    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isTrue);

    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isFalse);
    await disposeTideApp(tester, db);
  });

  testWidgets('counted habits show a gentle caption', (tester) async {
    late Habit water;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      water = (await HabitRepository(db, clock).add(name: 'Water', icon: 'water', dailyTarget: 8))!;
    });
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('habit-${water.id}')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Water 3 of 8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Water 3 of 8'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('a new day starts fresh while the app stays open', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 21));
    late Habit read;
    final db = await pumpTideApp(tester, clock: clock, seed: (db, clock) async {
      read = (await HabitRepository(db, clock).add(name: 'Read', icon: 'book'))!;
    });
    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isTrue);

    clock.set(DateTime(2026, 9, 29, 7));
    ProviderScope.containerOf(tester.element(find.byType(HabitsCard)))
        .read(nowProvider.notifier)
        .refresh();
    await tester.pumpAndSettle();

    expect(circle(tester, read).item.done, isFalse);
    expect(find.text('Tuesday, 29 Sep'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
