import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/check_in_repository.dart';
import 'package:tide/features/checkin/providers.dart';
import 'package:tide/features/journal/journal_screen.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/widgets/autosave_field.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('an edit made in the Journal is not overwritten by the Today card', (tester) async {
    final db = await pumpTideApp(tester);
    await tester.enterText(find.widgetWithText(TextField, 'What would make today good?'), 'Run');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday, 28 Sep'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Run'), 'Run 5k');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Run 5k'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping an older day scrolls to its entry instead of opening the editor',
      (tester) async {
    Future<void> seed(AppDatabase db, FakeClock clock) async {
      final repo = CheckInRepository(db, clock);
      for (var d = 2; d <= 27; d++) {
        await repo.saveReflection('2026-09-${d.toString().padLeft(2, '0')}',
            'Day $d was long and full, with plenty to say about it.\nMore lines.\nAnd more.');
      }
    }

    final db = await pumpTideApp(tester, seed: seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-2026-09-02')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('How was the day?'), findsNothing);
    expect(find.text('Wednesday, 2 Sep'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('the journal does not flash its empty message while loading', (tester) async {
    final db = await pumpTideApp(tester, overrides: [
      journalEntriesProvider.overrideWith((ref) => StreamController<List<CheckIn>>().stream),
    ]);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Your check-ins will gather here, day by day.'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('typing is saved straight away when the app goes to the background', (tester) async {
    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Scaffold(
        body: AutosaveField(initialValue: null, hint: 'hint', onSave: (v) async => saved.add(v)),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Last words');
    await tester.pump(const Duration(milliseconds: 100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(saved, ['Last words']);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(saved, ['Last words']); // not saved twice
  });

  testWidgets("a check-in that fails to load says so instead of vanishing", (tester) async {
    final db = await pumpTideApp(tester, overrides: [
      checkInForDayProvider.overrideWith((ref, date) => Stream<CheckIn?>.error(Exception('disk'))),
    ]);
    expect(find.text("Couldn't load today's check-in."), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
