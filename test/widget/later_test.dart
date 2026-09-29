import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('undated tasks wait in Later and can be moved to today', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Sort photos');
    });
    expect(find.text('Sort photos'), findsNothing);
    expect(find.text('Later · 1'), findsOneWidget);

    await tester.tap(find.text('Later · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Sort photos'), findsOneWidget);

    await tester.tap(find.text('Do today'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing for later'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sort photos'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
