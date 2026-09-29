import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/clock.dart';
import 'data/db/app_database.dart';
import 'data/maintenance.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startTide();
}

/// Opens the database defensively; recovery hooks in here.
Future<void> startTide() async {
  final db = AppDatabase.open();
  await db.select(db.appSettings).get();
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  runApp(UncontrolledProviderScope(container: container, child: const TideApp()));
  unawaited(runStartupTasks(
    maintenance: Maintenance(db, const SystemClock()),
    backups: container.read(backupServiceProvider),
  ));
}
