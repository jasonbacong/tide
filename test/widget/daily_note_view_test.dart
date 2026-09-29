import 'package:flutter_test/flutter_test.dart';
import 'package:tide/content/daily_lines.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('Today resurfaces a reflection from a month ago', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CheckInRepository(db, clock).saveReflection('2026-08-29', 'Slow mornings suit me.');
    });
    expect(find.text('A month ago you wrote: “Slow mornings suit me.”'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('otherwise shows one of the bundled lines', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text(dailyLines[20260928 % dailyLines.length]), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
