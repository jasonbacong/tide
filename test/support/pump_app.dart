import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/app.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';

import 'fake_clock.dart';
import 'test_db.dart';

typedef Seed = Future<void> Function(AppDatabase db, FakeClock clock);

/// Pumps the full app on an in-memory database. Defaults to Monday 28 Sep 2026, 09:00.
/// [seed] runs against the database before the app starts.
Future<AppDatabase> pumpTideApp(WidgetTester tester, {FakeClock? clock, Seed? seed}) async {
  final db = testDb();
  final fake = clock ?? FakeClock(DateTime(2026, 9, 28, 9));
  if (seed != null) await tester.runAsync(() => seed(db, fake));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(fake),
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
