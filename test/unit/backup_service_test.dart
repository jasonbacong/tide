import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_service.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/data/repositories/settings_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late Directory tmp;
  late BackupService service;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    tmp = Directory.systemTemp.createTempSync('tide_backup_test');
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

  test('first start writes a backup, then waits a week', () async {
    expect(await service.autoBackupIfDue(), isNotNull);
    clock.advance(const Duration(days: 6));
    expect(await service.autoBackupIfDue(), isNull);
    clock.advance(const Duration(days: 1));
    expect(await service.autoBackupIfDue(), isNotNull);
    expect(await service.listBackups(), hasLength(2));
  });

  test('keeps only the newest 4, newest first', () async {
    for (var i = 0; i < 6; i++) {
      await service.autoBackupIfDue();
      clock.advance(const Duration(days: 7));
    }
    final files = await service.listBackups();
    expect(files, hasLength(4));
    expect(backupStamp(files.first).compareTo(backupStamp(files.last)), greaterThan(0));
  });

  test('a last-backup time in the future counts as due', () async {
    await service.autoBackupIfDue();
    clock.set(DateTime(2026, 9, 20)); // clock moved backwards
    expect(await service.autoBackupIfDue(), isNotNull);
  });

  test('export writes a named .tide.json file that reads back', () async {
    await CaptureRepository(db, clock).add('Idea');
    final file = await service.exportFile();
    expect(file.path, endsWith('tide-backup-2026-09-28-090000.tide.json'));
    final data = await service.read(file);
    expect(data.captures.single.body, 'Idea');
  });

  test('restore saves a safety copy of the current data first', () async {
    await CaptureRepository(db, clock).add('current');
    final exported = await service.read(await service.exportFile());
    await CaptureRepository(db, clock).add('added after export');
    clock.advance(const Duration(seconds: 1));
    await service.restore(exported);

    expect((await db.select(db.captures).get()).map((c) => c.body), ['current']);
    final copies = await service.listBackups();
    expect(copies.any((f) => f.path.contains('before-restore-')), isTrue);
  });
}
