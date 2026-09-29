import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/settings_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('first launch asks for a name before anything else', (tester) async {
    final db = await pumpTideApp(tester, name: '');
    expect(find.text('Welcome to Tide'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Type your first name'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('starting saves the name and any picked habits', (tester) async {
    final db = await pumpTideApp(tester, name: '');
    await tester.enterText(find.widgetWithText(TextField, 'Your first name'), 'Jason');
    await tester.tap(find.text('Drink water'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Jason'), findsOneWidget);
    final habit = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(habit.name, 'Water');
    expect(habit.dailyTarget, 8);
    await disposeTideApp(tester, db);
  });

  testWidgets('the saved theme preference is applied', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await SettingsRepository(db, clock).setTheme(ThemePreference.dark);
    });
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await disposeTideApp(tester, db);
  });
}
