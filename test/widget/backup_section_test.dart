import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_codec.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/features/settings/backup_section.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('tide_ui_backup'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text('Good morning, Jason'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Export'), 200,
        scrollable: find.byType(Scrollable).last);
  }

  testWidgets('export shares a file and records the date', (tester) async {
    final shared = <File>[];
    final db = await pumpTideApp(tester, overrides: [
      shareFileProvider.overrideWithValue((f) async => shared.add(f)),
      backupDirsOverride(tmp),
    ]);
    await openSettings(tester);
    expect(find.text('Not exported yet'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(shared.single.path, endsWith('.tide.json'));
    expect(find.text('Last exported today'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('import asks first, then replaces everything', (tester) async {
    final file = File('${tmp.path}/in.tide.json');
    final clock = FakeClock(DateTime(2026, 9, 28, 9));
    final db = await pumpTideApp(tester, clock: clock, overrides: [
      pickFileProvider.overrideWithValue(() async => file),
      backupDirsOverride(tmp),
    ], seed: (db, c) async {
      await CaptureRepository(db, c).add('from backup');
      file.writeAsStringSync(BackupCodec.encode(await BackupCodec.export(db, c.now().toUtc())));
      await CaptureRepository(db, c).add('will be replaced');
    });
    await openSettings(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('This replaces everything in the app.'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Replace'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Backup restored'), findsOneWidget);
    final bodies = (await tester.runAsync(() => db.select(db.captures).get()))!.map((c) => c.body);
    expect(bodies, ['from backup']);
    await disposeTideApp(tester, db);
  });

  testWidgets('a wrong file shows a calm message and changes nothing', (tester) async {
    final file = File('${tmp.path}/notes.txt')..writeAsStringSync('hello');
    final db = await pumpTideApp(tester, overrides: [
      pickFileProvider.overrideWithValue(() async => file),
      backupDirsOverride(tmp),
    ]);
    await openSettings(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Import'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text("That file isn't a Tide backup."), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a fresh install can restore from the welcome screen', (tester) async {
    final file = File('${tmp.path}/in.tide.json');
    final db = await pumpTideApp(tester, name: '', overrides: [
      pickFileProvider.overrideWithValue(() async => file),
      backupDirsOverride(tmp),
    ], seed: (db, c) async {
      final other = BackupCodec.encode({
        'app': 'tide',
        'schemaVersion': 1,
        'tables': {
          for (final t in ['captures', 'tasks', 'habits', 'habit_ticks', 'check_ins', 'goals', 'milestones'])
            t: [],
          'app_settings': [
            {'id': 1, 'name': 'Jason', 'themeMode': 'system', 'lastExportAt': null, 'lastAutoBackupAt': null}
          ],
        },
      });
      file.writeAsStringSync(other);
    });
    expect(find.text('Welcome to Tide'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Restore from a backup'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Replace'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Jason'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
