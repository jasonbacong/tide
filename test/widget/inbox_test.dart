import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/today/inbox_line.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> capture(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), text);
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();
  }

  test('inboxLabel pluralises', () {
    expect(inboxLabel(1), '1 thought in your inbox');
    expect(inboxLabel(3), '3 thoughts in your inbox');
  });

  testWidgets('inbox line only appears when there is something to sort', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.textContaining('in your inbox'), findsNothing);

    await capture(tester, 'Book a table for Friday');
    expect(find.text('1 thought in your inbox'), findsOneWidget);

    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Book a table for Friday'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('archiving the last capture shows the empty state, and Undo restores it',
      (tester) async {
    final db = await pumpTideApp(tester);
    await capture(tester, 'Water the plants');
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Water the plants'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Water the plants'), findsNothing);
    expect(find.text('Nothing to sort'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Water the plants'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('long captures are truncated to four lines in the inbox', (tester) async {
    final db = await pumpTideApp(tester);
    final long = List.filled(400, 'word').join(' ');
    await capture(tester, long);
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 4);
    expect(text.overflow, TextOverflow.ellipsis);
    await disposeTideApp(tester, db);
  });

  testWidgets('the Archived message goes away on its own after about 4 seconds', (tester) async {
    final db = await pumpTideApp(tester);
    await capture(tester, 'Call the bank');
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Call the bank'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsNothing);
    await disposeTideApp(tester, db);
  });
}
