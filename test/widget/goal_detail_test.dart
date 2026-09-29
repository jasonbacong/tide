import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/goals/goals_screen.dart';
import 'package:tide/ui/widgets/progress_ring.dart';

import '../support/pump_app.dart';

void main() {
  late Goal goal;

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(goal.title));
    await tester.pumpAndSettle();
  }

  testWidgets('adding and ticking milestones fills the ring', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Run 10k', why: 'Feel strong'))!;
    });
    await open(tester);
    expect(find.text('Feel strong'), findsOneWidget);

    final field = find.widgetWithText(TextField, 'Add a milestone');
    await tester.enterText(field, 'Run 3k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'Run 5k');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final ms = await tester.runAsync(() => db.select(db.milestones).get());
    await tester.tap(find.byKey(ValueKey('milestone-${ms!.first.id}')));
    await tester.pumpAndSettle();
    expect(tester.widget<ProgressRing>(find.byType(ProgressRing)).progress, 0.5);
    await disposeTideApp(tester, db);
  });

  testWidgets('linked habits and tasks are listed', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Health'))!;
      await HabitRepository(db, clock).add(name: 'Walk', icon: 'walk', goalId: goal.id);
      await TaskRepository(db, clock).add(title: 'Book check-up', goalId: goal.id);
    });
    await open(tester);
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Book check-up'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('mark achieved blooms, moves to past, and ignores a double tap', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Learn to swim'))!;
    });
    await open(tester);
    await tester.tap(find.text('Mark achieved'));
    await tester.tap(find.text('Mark achieved'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsScreen), findsOneWidget);
    final row = (await tester.runAsync(() => db.select(db.goals).getSingle()))!;
    expect(row.status, GoalStatus.achieved);
    await disposeTideApp(tester, db);
  });

  testWidgets('let it go asks first', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Write a novel'))!;
    });
    await open(tester);
    await tester.tap(find.text('Let it go'));
    await tester.pumpAndSettle();
    expect(find.text('Let this goal go?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Let it go').last);
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.goals).getSingle()))!;
    expect(row.status, GoalStatus.letGo);
    await disposeTideApp(tester, db);
  });

  testWidgets('deleting a goal keeps its linked habit', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      goal = (await GoalRepository(db, clock).create(title: 'Health'))!;
      await HabitRepository(db, clock).add(name: 'Walk', icon: 'walk', goalId: goal.id);
    });
    await open(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    final habit = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(habit.goalId, isNull);
    expect(find.byType(GoalsScreen), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
