import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/app.dart';
import 'package:tide/data/backup/backup_service.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/settings_repository.dart';

import 'fake_clock.dart';
import 'test_db.dart';

typedef Seed = Future<void> Function(AppDatabase db, FakeClock clock);

/// Pumps the full app on an in-memory database. Defaults to Monday 28 Sep 2026, 09:00.
/// [seed] runs against the database before the app starts.
Future<AppDatabase> pumpTideApp(WidgetTester tester,
    {FakeClock? clock,
    Seed? seed,
    String name = 'Jason',
    List<Override> overrides = const []}) async {
  // Jason's Galaxy S24 Ultra: 1440×3120 px at ~3.5× → about 411×891 logical pixels.
  tester.view.physicalSize = const Size(1440, 3120);
  tester.view.devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final db = testDb();
  final fake = clock ?? FakeClock(DateTime(2026, 9, 28, 9));
  await tester.runAsync(() async {
    if (name.isNotEmpty) await SettingsRepository(db, fake).setName(name);
    if (seed != null) await seed(db, fake);
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(fake),
      ...overrides,
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

/// Points backups and exports at a temp directory for widget tests.
Override backupDirsOverride(Directory tmp) => backupServiceProvider.overrideWith((ref) => BackupService(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      settings: ref.watch(settingsRepositoryProvider),
      backupsDir: () async => Directory('${tmp.path}/backups'),
      exportDir: () async => Directory('${tmp.path}/export'),
    ));
