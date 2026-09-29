import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_tile.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('adding a task from Today shows it in the Tasks card', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Nothing planned. Add something small.'), findsOneWidget);
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Call the dentist'), 'Call the dentist');
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Call the dentist'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('completing a task moves it below the open ones, struck through', (tester) async {
    late Task a;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = TaskRepository(db, clock);
      a = (await repo.add(title: 'First', date: '2026-09-28'))!;
      await repo.add(title: 'Second', date: '2026-09-28');
    });
    expect(tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Second')).dy));

    await tester.tap(find.byKey(ValueKey('check-${a.id}')));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('First')).dy,
        greaterThan(tester.getTopLeft(find.text('Second')).dy));
    final tile = tester.widget<TaskTile>(find.ancestor(
        of: find.text('First'), matching: find.byType(TaskTile)));
    expect(tile.task.isDone, isTrue);
    await disposeTideApp(tester, db);
  });

  testWidgets("yesterday's unfinished task rolls forward quietly", (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Reply to Sam', date: '2026-09-27');
    });
    expect(find.text('Reply to Sam'), findsOneWidget);
    expect(find.textContaining('overdue', findRichText: true), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('filters narrow by energy and time, and say when nothing matches', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = TaskRepository(db, clock);
      await repo.add(title: 'Easy call', energy: Energy.low, minutes: 15, date: '2026-09-28');
      await repo.add(title: 'Deep work', energy: Energy.high, minutes: 60, date: '2026-09-28');
      await repo.add(title: 'Untagged', date: '2026-09-28');
    });

    await tester.tap(find.text('Low'));
    await tester.pumpAndSettle();
    expect(find.text('Easy call'), findsOneWidget);
    expect(find.text('Deep work'), findsNothing);
    expect(find.text('Untagged'), findsNothing);

    await tester.tap(find.text('High'));
    await tester.tap(find.text('≤ 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches. Try another filter.'), findsOneWidget);

    await tester.tap(find.text('High'));
    await tester.tap(find.text('≤ 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Untagged'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('deleting the last task shows the hint, and Undo brings it back', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Pay rent', date: '2026-09-28');
    });
    await tester.drag(find.text('Pay rent'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Pay rent'), findsNothing);
    expect(find.text('Nothing planned. Add something small.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Pay rent'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping a task title opens it for editing', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Draft email', date: '2026-09-28');
    });
    await tester.tap(find.text('Draft email'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
