import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_editor_sheet.dart';

import '../support/harness.dart';
import '../support/pump_app.dart';

void main() {
  Widget opener(BuildContext context, {Task? task, String? initialTitle}) => TextButton(
        onPressed: () => showTaskEditor(context, task: task, initialTitle: initialTitle),
        child: const Text('Open'),
      );

  testWidgets('saves a task for today with energy and time', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Call the dentist');
    await tester.tap(find.text('Low'));
    await tester.tap(find.text('15 min'));
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.title, 'Call the dentist');
    expect(row.energy, Energy.low);
    expect(row.minutes, 15);
    expect(row.date, '2026-09-28');
    await disposeTideApp(tester, db);
  });

  testWidgets('blank title shows a gentle error', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name first'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.tasks).get()), isEmpty);
    await disposeTideApp(tester, db);
  });

  testWidgets('Later saves with no date', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sort photos');
    await tester.tap(find.text('Later'));
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.date, isNull);
    await disposeTideApp(tester, db);
  });

  testWidgets('Pick a date defaults to tomorrow', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Book flights');
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Tue, 29 Sep'), findsOneWidget);
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.date, '2026-09-29');
    await disposeTideApp(tester, db);
  });

  testWidgets('initialTitle prefills a new task', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c, initialTitle: 'From inbox'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('From inbox'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
