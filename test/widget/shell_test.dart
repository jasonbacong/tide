import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/goals/goals_screen.dart';
import 'package:tide/features/journal/journal_screen.dart';
import 'package:tide/features/today/today_screen.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('Today shows the date and a morning greeting', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Monday, 28 Sep'), findsOneWidget);
    expect(find.text('Good morning, Jason'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('greeting follows the clock into the evening', (tester) async {
    final db = await pumpTideApp(tester, clock: FakeClock(DateTime(2026, 9, 28, 18)));
    expect(find.text('Good evening, Jason'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('bottom bar switches between Today, Goals and Journal', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalsScreen), findsOneWidget);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.byType(JournalScreen), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Jason'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
