import 'package:drift/drift.dart';

import '../enums.dart';

/// Columns every synced record carries (spec §5.4).
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CaptureRow')
class Captures extends Table with SyncColumns {
  TextColumn get body => text()();
  TextColumn get status => textEnum<CaptureStatus>()();
}

@DataClassName('TaskRow')
class Tasks extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get energy => textEnum<Energy>().nullable()();
  IntColumn get minutes => integer().nullable()();
  TextColumn get date => text().nullable()();
  TextColumn get goalId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('HabitRow')
class Habits extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get dailyTarget => integer().withDefault(const Constant(1))();
  TextColumn get goalId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('HabitTickRow')
class HabitTicks extends Table with SyncColumns {
  TextColumn get habitId => text()();
  TextColumn get date => text()();
  IntColumn get count => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {habitId, date},
      ];
}

@DataClassName('CheckInRow')
class CheckIns extends Table with SyncColumns {
  TextColumn get date => text().unique()();
  TextColumn get intention => text().nullable()();
  // Drift's documented pattern for a column CHECK that references itself.
  // ignore: recursive_getters
  IntColumn get mood => integer().nullable().check(mood.isBetweenValues(1, 5))();
  TextColumn get reflection => text().nullable()();
}

@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get why => text().nullable()();
  TextColumn get targetSeason => text().nullable()();
  TextColumn get status => textEnum<GoalStatus>()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('MilestoneRow')
class Milestones extends Table with SyncColumns {
  TextColumn get goalId => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// Single local-only row (id = 1). Not synced.
@DataClassName('SettingsRow')
class AppSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get themeMode =>
      textEnum<ThemePreference>().withDefault(const Constant('system'))();
  DateTimeColumn get lastExportAt => dateTime().nullable()();
  DateTimeColumn get lastAutoBackupAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
