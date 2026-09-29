import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/settings/settings_screen.dart';

import '../support/pump_app.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Good morning, Jason'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the greeting opens settings without the tab bar', (
    tester,
  ) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets(
    'changing the name updates the greeting; a blank name is ignored',
    (tester) async {
      final db = await pumpTideApp(tester);
      await _openSettings(tester);
      final field = find.widgetWithText(TextField, 'Jason');
      await tester.enterText(field, 'Jay');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.widgetWithText(TextField, 'Jay'), '   ');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Good morning, Jay'), findsOneWidget);
      await disposeTideApp(tester, db);
    },
  );

  testWidgets('theme can be set to dark', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await disposeTideApp(tester, db);
  });

  testWidgets('habits are listed and editable from settings', (tester) async {
    final db = await pumpTideApp(
      tester,
      seed: (db, clock) async {
        await HabitRepository(
          db,
          clock,
        ).add(name: 'Water', icon: 'water', dailyTarget: 8);
      },
    );
    await _openSettings(tester);
    expect(find.text('8 times a day'), findsOneWidget);
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.text('Edit habit'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('about says the data stays on the phone', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Tide 1.0.0'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('stays on this phone'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
