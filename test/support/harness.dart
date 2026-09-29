import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';

import 'fake_clock.dart';
import 'test_db.dart';

/// Pumps a single widget (built by [builder]) inside the Tide theme and providers.
/// Dispose with disposeTideApp.
Future<AppDatabase> pumpHarness(WidgetTester tester, WidgetBuilder builder,
    {FakeClock? clock}) async {
  final db = testDb();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock ?? FakeClock(DateTime(2026, 9, 28, 9))),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Scaffold(body: Center(child: Builder(builder: builder))),
    ),
  ));
  await tester.pumpAndSettle();
  return db;
}
