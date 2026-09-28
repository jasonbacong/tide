import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/app.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';

import 'fake_clock.dart';
import 'test_db.dart';

/// Pumps the full app on an in-memory database. Defaults to Monday 28 Sep 2026, 09:00.
Future<AppDatabase> pumpTideApp(WidgetTester tester, {FakeClock? clock}) async {
  final db = testDb();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock ?? FakeClock(DateTime(2026, 9, 28, 9))),
    ],
    child: const TideApp(),
  ));
  await tester.pumpAndSettle();
  return db;
}

/// Tears the tree down first so providers cancel timers and streams, then closes the DB.
Future<void> disposeTideApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  // Drift cancels stream queries on a timer; let fake time run so it can finish.
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}
