import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Captures,
  Tasks,
  Habits,
  HabitTicks,
  CheckIns,
  Goals,
  Milestones,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.preMigrationDir});

  /// Where a copy of the database goes before any schema upgrade (spec §6).
  final Future<Directory?> Function()? preMigrationDir;

  static Future<Directory> _documents() => getApplicationDocumentsDirectory();

  /// drift_flutter's default location: `<documents>/tide.sqlite`. Must never change.
  static Future<File> databaseFile() async => File('${(await _documents()).path}/tide.sqlite');

  factory AppDatabase.open() => AppDatabase(
        driftDatabase(name: 'tide', native: const DriftNativeOptions(databaseDirectory: _documents)),
        preMigrationDir: () async => Directory('${(await _documents()).path}/backups'),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        },
        onUpgrade: (m, from, to) async {
          final dir = await preMigrationDir?.call();
          if (dir != null) {
            await dir.create(recursive: true);
            final copy = File('${dir.path}/pre-migration-v$from.sqlite');
            if (await copy.exists()) await copy.delete();
            await customStatement("VACUUM INTO '${copy.path.replaceAll("'", "''")}'");
          }
          // Future schema steps go here, e.g. if (from < 2) { ... }
        },
      );
}
