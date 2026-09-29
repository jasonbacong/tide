import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/habits/habit_editor_sheet.dart';
import 'package:tide/features/habits/habit_icons.dart';

import '../support/fake_clock.dart';
import '../support/harness.dart';
import '../support/pump_app.dart';

void main() {
  test('there are 24 habit icons', () {
    expect(habitIcons, hasLength(24));
    expect(iconFor('nope'), Icons.circle_outlined);
  });

  testWidgets('creates a habit with an icon and a daily target', (tester) async {
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Water');
    await tester.tap(find.byTooltip('water'));
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byTooltip('More'));
    }
    await tester.pump();
    expect(find.text('8 times a day'), findsOneWidget);
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(row.name, 'Water');
    expect(row.icon, 'water');
    expect(row.dailyTarget, 8);
    await disposeTideApp(tester, db);
  });

  testWidgets('blank name shows a gentle error', (tester) async {
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name first'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a ninth habit shows the keep-it-light note but still saves', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 9));
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')), clock: clock);
    await tester.runAsync(() async {
      final repo = HabitRepository(db, clock);
      for (var i = 0; i < 8; i++) {
        await repo.add(name: 'h$i', icon: 'book');
      }
    });
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Keeping it light'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ninth');
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => db.select(db.habits).get()), hasLength(9));
    await disposeTideApp(tester, db);
  });

  testWidgets('archiving asks first, then hides the habit', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 9));
    late Habit habit;
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c, habit: habit), child: const Text('Open')),
        clock: clock);
    habit = (await tester.runAsync<Habit?>(
        () => HabitRepository(db, clock).add(name: 'Stretch', icon: 'yoga')))!;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
    await tester.tap(find.text('Archive habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(row.archived, isTrue);
    await disposeTideApp(tester, db);
  });
}
