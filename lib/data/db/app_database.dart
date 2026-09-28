import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  AppDatabase(super.executor);

  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'tide'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        },
      );
}
