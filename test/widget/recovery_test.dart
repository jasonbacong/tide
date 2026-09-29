import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_codec.dart';
import 'package:tide/features/recovery/recovery_app.dart';

class _FakeActions implements RecoveryActions {
  _FakeActions({this.latest, this.picked, this.fail = false});

  final File? latest;
  final File? picked;
  final bool fail;
  File? restoredFrom;

  @override
  Future<File?> latestBackup() async => latest;

  @override
  Future<File?> pickFile() async => picked;

  @override
  Future<void> resetWith(File backup) async {
    if (fail) throw const BackupFormatException(BackupFormatException.notTide);
    restoredFrom = backup;
  }
}

void main() {
  testWidgets('offers the latest backup and recovers with it', (tester) async {
    final actions = _FakeActions(latest: File('/b/tide-backup-2026-09-21-090000.tide.json'));
    var recovered = false;
    await tester.pumpWidget(RecoveryApp(actions: actions, onRecovered: () async => recovered = true));
    await tester.pumpAndSettle();

    expect(find.text("Tide couldn't open your data"), findsOneWidget);
    await tester.tap(find.text('Restore latest backup'));
    await tester.pumpAndSettle();
    expect(actions.restoredFrom!.path, contains('2026-09-21'));
    expect(recovered, isTrue);
  });

  testWidgets('without backups only import is offered, and bad files explain themselves',
      (tester) async {
    final actions = _FakeActions(picked: File('/x/notes.txt'), fail: true);
    await tester.pumpWidget(RecoveryApp(actions: actions, onRecovered: () async {}));
    await tester.pumpAndSettle();
    expect(find.text('Restore latest backup'), findsNothing);
    await tester.tap(find.text('Import a file'));
    await tester.pumpAndSettle();
    expect(find.text("That file isn't a Tide backup."), findsOneWidget);
  });
}
