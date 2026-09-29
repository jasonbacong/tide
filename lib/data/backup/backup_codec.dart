import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  static const notTide = "That file isn't a Tide backup.";
  static const newer = 'This backup is from a newer version of Tide.';

  final String message;

  @override
  String toString() => message;
}

class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.captures,
    required this.tasks,
    required this.habits,
    required this.habitTicks,
    required this.checkIns,
    required this.goals,
    required this.milestones,
    required this.settings,
  });

  final DateTime? exportedAt;
  final List<CaptureRow> captures;
  final List<TaskRow> tasks;
  final List<HabitRow> habits;
  final List<HabitTickRow> habitTicks;
  final List<CheckInRow> checkIns;
  final List<GoalRow> goals;
  final List<MilestoneRow> milestones;
  final List<SettingsRow> settings;
}

abstract final class BackupCodec {
  static const schemaVersion = 1;

  /// ISO strings keep UTC ("…Z") intact through the round trip.
  static const _serializer = ValueSerializer.defaults(serializeDateTimeValuesAsString: true);

  static Future<Map<String, Object?>> export(AppDatabase db, DateTime nowUtc) async {
    List<Map<String, dynamic>> rows(List<DataClass> list) =>
        [for (final r in list) r.toJson(serializer: _serializer)];
    return {
      'app': 'tide',
      'schemaVersion': schemaVersion,
      'exportedAt': nowUtc.toIso8601String(),
      'tables': {
        'captures': rows(await db.select(db.captures).get()),
        'tasks': rows(await db.select(db.tasks).get()),
        'habits': rows(await db.select(db.habits).get()),
        'habit_ticks': rows(await db.select(db.habitTicks).get()),
        'check_ins': rows(await db.select(db.checkIns).get()),
        'goals': rows(await db.select(db.goals).get()),
        'milestones': rows(await db.select(db.milestones).get()),
        'app_settings': rows(await db.select(db.appSettings).get()),
      },
    };
  }

  static String encode(Map<String, Object?> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  static BackupData parse(String source) {
    const notTide = BackupFormatException(BackupFormatException.notTide);
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw notTide;
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'tide') throw notTide;
    final version = decoded['schemaVersion'];
    if (version is! int) throw notTide;
    if (version > schemaVersion) throw const BackupFormatException(BackupFormatException.newer);
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) throw notTide;

    List<T> list<T>(
        String key, T Function(Map<String, dynamic> json, {ValueSerializer? serializer}) fromJson) {
      final raw = tables[key];
      if (raw is! List) throw notTide;
      try {
        return [
          for (final r in raw) fromJson((r as Map).cast<String, dynamic>(), serializer: _serializer),
        ];
      } catch (_) {
        throw notTide;
      }
    }

    return BackupData(
      exportedAt: DateTime.tryParse(decoded['exportedAt'] as String? ?? ''),
      captures: list('captures', CaptureRow.fromJson),
      tasks: list('tasks', TaskRow.fromJson),
      habits: list('habits', HabitRow.fromJson),
      habitTicks: list('habit_ticks', HabitTickRow.fromJson),
      checkIns: list('check_ins', CheckInRow.fromJson),
      goals: list('goals', GoalRow.fromJson),
      milestones: list('milestones', MilestoneRow.fromJson),
      settings: list('app_settings', SettingsRow.fromJson),
    );
  }

  /// Replaces everything in one transaction: any failure leaves the old data.
  static Future<void> restore(AppDatabase db, BackupData data) => db.transaction(() async {
        for (final table in db.allTables) {
          await db.delete(table).go();
        }
        await db.batch((b) {
          b.insertAll(db.captures, data.captures);
          b.insertAll(db.tasks, data.tasks);
          b.insertAll(db.habits, data.habits);
          b.insertAll(db.habitTicks, data.habitTicks);
          b.insertAll(db.checkIns, data.checkIns);
          b.insertAll(db.goals, data.goals);
          b.insertAll(db.milestones, data.milestones);
          b.insertAll(db.appSettings, data.settings);
        });
        if (data.settings.isEmpty) {
          await db.into(db.appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        }
      });
}
