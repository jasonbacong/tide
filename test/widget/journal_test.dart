import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/check_in_repository.dart';
import 'package:tide/features/journal/journal_screen.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

Future<void> _seed(AppDatabase db, FakeClock clock) async {
  final repo = CheckInRepository(db, clock);
  await repo.saveMood('2026-09-27', 4);
  await repo.saveReflection('2026-09-27', 'Quiet day by the sea.');
  await repo.saveIntention('2026-09-20', 'Call Nan');
}

void main() {
  testWidgets('shows the month with mood dots and entries newest first', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();

    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-09-27-4')), findsOneWidget);
    expect(find.text('Sunday, 27 Sep'), findsOneWidget);
    expect(find.text('Quiet day by the sea.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Sunday, 27 Sep')).dy,
        lessThan(tester.getTopLeft(find.text('Sunday, 20 Sep')).dy));
    await disposeTideApp(tester, db);
  });

  testWidgets('previous month and back; next is disabled on the current month', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);
    await disposeTideApp(tester, db);
  });

  testWidgets('future days do nothing', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-2026-09-30')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('Wednesday, 30 Sep'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('an empty journal invites the first check-in', (tester) async {
    final db = await pumpTideApp(tester);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Your check-ins will gather here, day by day.'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('opening an entry lets you edit that day', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiet day by the sea.'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, 27 Sep'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Quiet day by the sea.'), 'Quiet day by the sea. Swam.');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => (db.select(db.checkIns)
          ..where((c) => c.date.equals('2026-09-27')))
        .getSingle()))!;
    expect(row.reflection, 'Quiet day by the sea. Swam.');
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping an empty past day opens its editor', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-2026-09-25')));
    await tester.pumpAndSettle();
    expect(find.text('Friday, 25 Sep'), findsOneWidget);
    expect(find.text('How was the day?'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
