import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/goals/goals_screen.dart';
import 'package:tide/features/goals/providers.dart';

import '../support/pump_app.dart';

void main() {
  late Goal goal;

  Future<void> openGoal(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(goal.title));
    await tester.pumpAndSettle();
  }

  testWidgets('leaving during the achieve moment does not crash or strand the Goals tab',
      (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Learn to swim'))!;
    });
    await openGoal(tester);
    await tester.tap(find.text('Mark achieved'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Today'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);
    expect(find.text('Mark achieved'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('pressing back during the achieve moment does not crash', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Learn to swim'))!;
    });
    await openGoal(tester);
    await tester.tap(find.text('Mark achieved'));
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a goal that fails to load says so and can be left', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Health'))!;
    }, overrides: [
      goalProvider.overrideWith((ref, id) => Stream<Goal?>.error(Exception('disk'))),
    ]);
    await openGoal(tester);
    expect(find.text("Couldn't load this goal."), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('the linked hint does not flash while linked items load', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Health'))!;
    }, overrides: [
      linkedHabitsProvider.overrideWith((ref, id) => StreamController<List<Habit>>().stream),
    ]);
    await openGoal(tester);
    expect(find.text('Link habits and tasks to this goal from their editors.'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('Later shows the goal line too', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Health'))!;
      await TaskRepository(db, clock).add(title: 'Book check-up', goalId: goal.id);
    });
    await tester.tap(find.text('Later · 1'));
    await tester.pumpAndSettle();
    expect(find.text('→ Health'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a task linked to a past goal can be unlinked', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final goals = GoalRepository(db, clock);
      goal = (await goals.create(title: 'Swim a mile'))!;
      await TaskRepository(db, clock).add(title: 'Pool session', date: '2026-09-28', goalId: goal.id);
      await goals.markAchieved(goal.id);
    });
    await tester.tap(find.text('Pool session'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Swim a mile'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final task = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(task.goalId, isNull);
    await disposeTideApp(tester, db);
  });
}
