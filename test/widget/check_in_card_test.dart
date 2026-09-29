import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('morning shows the intention card and saves what you type', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Intention'), findsOneWidget);
    expect(find.text('What would make today good?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'An unhurried lunch');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.date, '2026-09-28');
    expect(row.intention, 'An unhurried lunch');
    await disposeTideApp(tester, db);
  });

  testWidgets('from 17:00 the reflection card shows the morning intention, mood and note',
      (tester) async {
    final db = await pumpTideApp(tester, clock: FakeClock(DateTime(2026, 9, 28, 17)),
        seed: (db, clock) async {
      await CheckInRepository(db, clock).saveIntention('2026-09-28', 'Be kind to myself');
    });
    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('This morning: Be kind to myself'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mood-4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Quiet and good.');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.mood, 4);
    expect(row.reflection, 'Quiet and good.');
    await disposeTideApp(tester, db);
  });

  testWidgets('a late reflection is kept and the next day starts with an intention',
      (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 50));
    final db = await pumpTideApp(tester, clock: clock);
    await tester.enterText(find.byType(TextField), 'Long day, glad it is done.');
    await tester.pump(const Duration(milliseconds: 700));

    clock.set(DateTime(2026, 9, 29, 0, 10));
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    // the minute timer refreshes nowProvider
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('Intention'), findsOneWidget);
    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.date, '2026-09-28');
    expect(row.reflection, 'Long day, glad it is done.');
    await disposeTideApp(tester, db);
  });
}
