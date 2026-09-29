import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/ui/widgets/progress_ring.dart';

import '../support/pump_app.dart';

Future<void> _openGoals(WidgetTester tester) async {
  await tester.tap(find.text('Goals'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty screen invites a goal and creating one shows its card', (tester) async {
    final db = await pumpTideApp(tester);
    await _openGoals(tester);
    expect(find.text('What would you like to work towards?'), findsOneWidget);

    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Read 12 books this year'), 'Read 12 books');
    await tester.enterText(find.widgetWithText(TextField, 'By when, roughly (by spring)'), 'by December');
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect(find.text('Read 12 books'), findsOneWidget);
    expect(find.text('by December'), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('a sixth goal shows the limit message instead of the editor', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = GoalRepository(db, clock);
      for (var i = 1; i <= 5; i++) {
        await repo.create(title: 'Goal $i');
      }
    });
    await _openGoals(tester);
    await tester.tap(find.text('New goal'));
    await tester.pumpAndSettle();
    expect(find.text('You have 5 goals already. Finish or let one go first.'), findsOneWidget);
    expect(find.text('Save goal'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('past goals sit in a collapsed section', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = GoalRepository(db, clock);
      final g = await repo.create(title: 'Learn to swim');
      await repo.markAchieved(g!.id);
    });
    await _openGoals(tester);
    expect(find.text('Learn to swim'), findsNothing);
    await tester.tap(find.text('Past goals'));
    await tester.pumpAndSettle();
    expect(find.text('Learn to swim'), findsOneWidget);
    expect(find.text('Achieved · Sep 2026'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a goal with milestones shows a ring', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = GoalRepository(db, clock);
      final g = await repo.create(title: 'Run 10k');
      await repo.addMilestone(g!.id, '3k');
    });
    await _openGoals(tester);
    expect(find.byType(ProgressRing), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
