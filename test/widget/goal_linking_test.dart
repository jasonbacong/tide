import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a task linked in the editor shows a quiet goal line on Today', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await GoalRepository(db, clock).create(title: 'Read 12 books');
    });
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Call the dentist'), 'Read chapter 3');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Read 12 books'));
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('→ Read 12 books'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a task linked to a past goal keeps its line', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final goals = GoalRepository(db, clock);
      final g = await goals.create(title: 'Swim a mile');
      await TaskRepository(db, clock).add(title: 'Pool session', date: '2026-09-28', goalId: g!.id);
      await goals.markAchieved(g.id);
    });
    expect(find.text('→ Swim a mile'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a linked habit shows its goal in the history sheet', (tester) async {
    late Habit walk;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final g = await GoalRepository(db, clock).create(title: 'Health');
      walk = (await HabitRepository(db, clock).add(name: 'Walk', icon: 'walk', goalId: g!.id))!;
    });
    await tester.longPress(find.byKey(ValueKey('habit-${walk.id}')));
    await tester.pumpAndSettle();
    expect(find.text('→ Health'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('the goal section is hidden when there are no goals', (tester) async {
    final db = await pumpTideApp(tester);
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    expect(find.text('Goal'), findsNothing);
    await disposeTideApp(tester, db);
  });
}
