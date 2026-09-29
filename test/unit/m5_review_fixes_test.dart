import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_codec.dart';
import 'package:tide/data/backup/backup_service.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/data/repositories/settings_repository.dart';
import 'package:tide/features/recovery/recovery_app.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late Directory tmp;
  late BackupService service;

  setUp(() async {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    await SettingsRepository(db, clock).setName('Jason');
    tmp = Directory.systemTemp.createTempSync('tide_m5_fix');
    service = BackupService(
      db: db,
      clock: clock,
      settings: SettingsRepository(db, clock),
      backupsDir: () async => Directory('${tmp.path}/backups'),
      exportDir: () async => Directory('${tmp.path}/export'),
    );
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('restore safety copies never push out the automatic backups', () async {
    for (var i = 0; i < 3; i++) {
      await service.autoBackupIfDue();
      clock.advance(const Duration(days: 7));
    }
    final data = await service.read(await service.exportFile());
    for (var i = 0; i < 5; i++) {
      clock.advance(const Duration(minutes: 1));
      await service.restore(data);
    }
    final names = (await service.listBackups()).map((f) => f.path.split('/').last).toList();
    expect(names.where((n) => n.startsWith('tide-backup-')), hasLength(3));
    expect(names.where((n) => n.startsWith('before-restore-')), hasLength(4));
  });

  test('after the clock jumps back, the new backup survives and is listed first', () async {
    clock.set(DateTime(2026, 10, 28, 9)); // clock running a month fast
    for (var i = 0; i < 4; i++) {
      await service.autoBackupIfDue();
      clock.advance(const Duration(days: 7));
    }
    clock.set(DateTime(2026, 9, 28, 10)); // corrected
    final fresh = await service.autoBackupIfDue();
    expect(fresh, isNotNull);
    expect(fresh!.existsSync(), isTrue);
    expect((await service.listBackups()).first.path, fresh.path);
  });

  test('no automatic backup is written before the app has been set up', () async {
    await db.customStatement("UPDATE app_settings SET name = ''");
    expect(await service.autoBackupIfDue(), isNull);
    expect(await service.listBackups(), isEmpty);
  });

  test('a backup whose settings row is broken is rejected', () async {
    final map = await BackupCodec.export(db, clock.now().toUtc());
    (((map['tables'] as Map)['app_settings'] as List).single as Map)['id'] = 7;
    expect(() => BackupCodec.parse(jsonEncode(map)), throwsA(isA<BackupFormatException>()));
  });

  group('device recovery', () {
    late Directory docs;
    late File backup;
    late DeviceRecoveryActions actions;

    setUp(() async {
      docs = Directory('${tmp.path}/docs')..createSync();
      await CaptureRepository(db, clock).add('from backup');
      backup = await service.exportFile();
      actions = DeviceRecoveryActions(documentsDir: () async => docs);
    });

    test('a successful restore replaces the broken database', () async {
      File('${docs.path}/tide.sqlite').writeAsStringSync('not a database');
      await actions.resetWith(backup);
      final restored = AppDatabase(NativeDatabase(File('${docs.path}/tide.sqlite')));
      addTearDown(restored.close);
      expect((await restored.select(restored.captures).get()).single.body, 'from backup');
      expect(docs.listSync().any((e) => e.path.contains('tide-broken-')), isTrue);
    });

    test('a failed restore leaves the original database where it was', () async {
      File('${docs.path}/tide.sqlite').writeAsStringSync('not a database');
      final map = jsonDecode(backup.readAsStringSync()) as Map<String, dynamic>;
      final caps = (map['tables'] as Map)['captures'] as List;
      caps.add(Map<String, dynamic>.from(caps.first as Map)); // duplicate id → restore throws
      final bad = File('${tmp.path}/bad.tide.json')..writeAsStringSync(jsonEncode(map));

      await expectLater(actions.resetWith(bad), throwsA(anything));
      expect(File('${docs.path}/tide.sqlite').readAsStringSync(), 'not a database');
      expect(docs.listSync().any((e) => e.path.contains('tide-broken-')), isFalse);
      expect(docs.listSync().any((e) => e.path.contains('restoring')), isFalse);
    });
  });
}
