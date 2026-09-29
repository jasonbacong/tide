import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/maintenance.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

class _V2 extends AppDatabase {
  _V2(super.executor, {super.preMigrationDir});

  @override
  int get schemaVersion => 2;
}

void main() {
  test('purges tombstones older than 30 days only', () async {
    final db = testDb();
    addTearDown(db.close);
    final clock = FakeClock(DateTime(2026, 8, 1, 9));
    final tasks = TaskRepository(db, clock);
    final old = await tasks.add(title: 'old', date: '2026-08-01');
    await tasks.delete(old!.id);
    clock.set(DateTime(2026, 9, 20, 9));
    final recent = await tasks.add(title: 'recent', date: '2026-09-20');
    await tasks.delete(recent!.id);
    await tasks.add(title: 'alive', date: '2026-09-20');
    await CaptureRepository(db, clock).add('kept');

    clock.set(DateTime(2026, 9, 28, 9));
    expect(await Maintenance(db, clock).purgeTombstones(), 1);
    expect((await db.select(db.tasks).get()).map((t) => t.title), unorderedEquals(['recent', 'alive']));
  });

  test('upgrading takes a copy of the database first', () async {
    final tmp = Directory.systemTemp.createTempSync('tide_migration');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final file = File('${tmp.path}/tide.sqlite');

    final v1 = AppDatabase(NativeDatabase(file));
    await v1.select(v1.appSettings).get();
    await v1.close();

    final v2 = _V2(NativeDatabase(file), preMigrationDir: () async => Directory('${tmp.path}/backups'));
    await v2.select(v2.appSettings).get();
    await v2.close();

    final copy = File('${tmp.path}/backups/pre-migration-v1.sqlite');
    expect(copy.existsSync(), isTrue);
    expect(copy.lengthSync(), greaterThan(0));
  });
}
