import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_codec.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/data/repositories/check_in_repository.dart';
import 'package:tide/data/repositories/goal_repository.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/settings_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

Future<Map<String, List<Map<String, Object?>>>> _dump(AppDatabase db) async => {
      for (final t in db.allTables)
        t.actualTableName: [
          for (final r in await db.customSelect('SELECT * FROM ${t.actualTableName} ORDER BY 1').get())
            r.data,
        ],
    };

void main() {
  late AppDatabase source;
  late FakeClock clock;

  setUp(() async {
    source = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9, 30, 0, 123));
    await CaptureRepository(source, clock).add('Idea 🌊');
    final tasks = TaskRepository(source, clock);
    final t = await tasks.add(title: 'Call', energy: Energy.low, minutes: 15, date: '2026-09-28');
    await tasks.complete(t!.id);
    final habits = HabitRepository(source, clock);
    final h = await habits.add(name: 'Water', icon: 'water', dailyTarget: 8);
    await habits.tap(h!.id, '2026-09-28');
    await CheckInRepository(source, clock).saveMood('2026-09-28', 4);
    final goals = GoalRepository(source, clock);
    final g = await goals.create(title: 'Read 12 books');
    await goals.addMilestone(g!.id, 'First book');
    await SettingsRepository(source, clock).setName('Jason');
  });
  tearDown(() => source.close());

  test('export → encode → parse → restore reproduces every table exactly', () async {
    final json = BackupCodec.encode(await BackupCodec.export(source, clock.now().toUtc()));
    final target = testDb();
    addTearDown(target.close);
    await BackupCodec.restore(target, BackupCodec.parse(json));
    expect(await _dump(target), await _dump(source));
  });

  test('the export is labelled and versioned', () async {
    final map = await BackupCodec.export(source, clock.now().toUtc());
    expect(map['app'], 'tide');
    expect(map['schemaVersion'], 1);
    expect((map['tables'] as Map).keys, containsAll(['captures', 'tasks', 'app_settings']));
  });

  test('rejects things that are not Tide backups', () {
    for (final bad in ['not json', '[]', '{"app":"other"}', '{"app":"tide","schemaVersion":1}']) {
      expect(() => BackupCodec.parse(bad),
          throwsA(isA<BackupFormatException>()
              .having((e) => e.message, 'message', BackupFormatException.notTide)));
    }
  });

  test('rejects newer backups', () {
    expect(() => BackupCodec.parse('{"app":"tide","schemaVersion":99,"tables":{}}'),
        throwsA(isA<BackupFormatException>()
            .having((e) => e.message, 'message', BackupFormatException.newer)));
  });

  test('rejects a malformed row', () async {
    final map = await BackupCodec.export(source, clock.now().toUtc());
    ((map['tables'] as Map)['tasks'] as List).add({'id': 1});
    expect(() => BackupCodec.parse(jsonEncode(map)), throwsA(isA<BackupFormatException>()));
  });

  test('a restore that fails leaves existing data untouched', () async {
    final map = await BackupCodec.export(source, clock.now().toUtc());
    final captures = (map['tables'] as Map)['captures'] as List;
    captures.add(Map<String, dynamic>.from(captures.first as Map)); // duplicate primary key
    final data = BackupCodec.parse(jsonEncode(map));

    final target = testDb();
    addTearDown(target.close);
    await CaptureRepository(target, clock).add('keep me');
    final before = await _dump(target);
    await expectLater(BackupCodec.restore(target, data), throwsA(anything));
    expect(await _dump(target), before);
  });
}
