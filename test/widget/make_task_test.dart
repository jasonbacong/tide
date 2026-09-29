import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/capture_repository.dart';

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
    await tester.tapAt(const Offset(20, 20)); // tap the barrier
    await tester.pumpAndSettle();
    expect(find.text('Maybe later'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
