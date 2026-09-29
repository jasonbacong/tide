import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'backup/backup_service.dart';
import 'clock.dart';
import 'db/app_database.dart';

class Maintenance {
  Maintenance(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  static const _synced = [
    'captures', 'tasks', 'habits', 'habit_ticks', 'check_ins', 'goals', 'milestones',
  ];

  /// Deletes rows whose tombstone is older than [olderThan] (spec §5.4).
  Future<int> purgeTombstones({Duration olderThan = const Duration(days: 30)}) async {
    final cutoff = _clock.now().toUtc().subtract(olderThan).toIso8601String();
    var total = 0;
    await _db.transaction(() async {
      for (final table in _synced) {
        total += await _db.customUpdate(
          'DELETE FROM $table WHERE deleted_at IS NOT NULL AND deleted_at < ?',
          variables: [Variable.withString(cutoff)],
          updateKind: UpdateKind.delete,
        );
      }
    });
    return total;
  }
}

/// Best-effort housekeeping on app start. Never throws.
Future<void> runStartupTasks({
  required Maintenance maintenance,
  required BackupService backups,
}) async {
  try {
    await maintenance.purgeTombstones();
  } catch (e) {
    debugPrint('Tombstone purge skipped: $e');
  }
  try {
    await backups.autoBackupIfDue();
  } catch (e) {
    debugPrint('Automatic backup skipped: $e');
  }
}
