import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving a thought closes the sheet and confirms', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);
    expect(find.text('Capture a thought'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), '  Book a table for Friday  ');
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Book a table for Friday'), findsNothing);
    expect(find.text('Saved to your inbox'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows!.single.body, 'Book a table for Friday');
    await disposeTideApp(tester, db);
  });

  testWidgets('blank text shows a gentle error and saves nothing', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), '   ');
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Type something first'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), 'x');
    await tester.pump();
    expect(find.text('Type something first'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('double-tapping save stores one capture', (tester) async {
    final db = await pumpTideApp(tester);
    await openSheet(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), 'Only once');
    await tester.tap(find.text('Save to inbox'));
    await tester.tap(find.text('Save to inbox'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => db.select(db.captures).get());
    expect(rows, hasLength(1));
    await disposeTideApp(tester, db);
  });
}
