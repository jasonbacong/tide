import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/data/repositories/goal_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('tapping a capture turns it into a task for today', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Book a table for Friday');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a table for Friday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make task'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to sort'), findsOneWidget);
    expect(find.text('Task added'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Book a table for Friday'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('closing the editor without saving leaves the capture in the inbox', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Maybe later');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make task'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // tap the barrier
    await tester.pumpAndSettle();
    expect(find.text('Maybe later'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('link to goal makes a linked task', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await GoalRepository(db, clock).create(title: 'Read 12 books');
      await CaptureRepository(db, clock).add('Buy the next book');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy the next book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link to goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read 12 books'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    final task = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    final goal = (await tester.runAsync(() => db.select(db.goals).getSingle()))!;
    expect(task.goalId, goal.id);
    expect(find.text('Nothing to sort'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('without goals the sheet offers Make task and Archive only', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Idea');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idea'));
    await tester.pumpAndSettle();
    expect(find.text('Link to goal'), findsNothing);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to sort'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
