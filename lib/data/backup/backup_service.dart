import 'dart:io';

import 'package:intl/intl.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../repositories/settings_repository.dart';
import 'backup_codec.dart';

final _stamp = RegExp(r'(\d{4}-\d{2}-\d{2}-\d{6})\.tide\.json$');

/// `yyyy-MM-dd-HHmmss` from a backup file name, or '' if it has none.
String backupStamp(File file) => _stamp.firstMatch(file.path)?.group(1) ?? '';

class BackupService {
  // Private named parameters: callers pass db:, clock:, settings:, backupsDir:, exportDir:.
  BackupService({
    required this._db,
    required this._clock,
    required this._settings,
    required this._backupsDir,
    required this._exportDir,
  });

  final AppDatabase _db;
  final Clock _clock;
  final SettingsRepository _settings;
  final Future<Directory> Function() _backupsDir;
  final Future<Directory> Function() _exportDir;

  static const keep = 4;
  static const interval = Duration(days: 7);

  Future<File> _write(Directory dir, String prefix) async {
    final now = _clock.now();
    await dir.create(recursive: true);
    final name = '$prefix-${DateFormat('yyyy-MM-dd-HHmmss').format(now)}.tide.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(BackupCodec.encode(await BackupCodec.export(_db, now.toUtc())));
    return file;
  }

  Future<File?> autoBackupIfDue() async {
    final last = (await _settings.read()).lastAutoBackupAt;
    final now = _clock.now();
    final due = last == null || last.isAfter(now) || now.difference(last) >= interval;
    if (!due) return null;
    final file = await _write(await _backupsDir(), 'tide-backup');
    await _settings.markAutoBackup();
    await _prune();
    return file;
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupsDir();
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.tide.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => backupStamp(b).compareTo(backupStamp(a)));
    return files;
  }

  Future<void> _prune() async {
    for (final old in (await listBackups()).skip(keep)) {
      await old.delete();
    }
  }

  Future<File> exportFile() async => _write(await _exportDir(), 'tide-backup');

  Future<BackupData> read(File file) async => BackupCodec.parse(await file.readAsString());

  Future<void> restore(BackupData data) async {
    await _write(await _backupsDir(), 'before-restore');
    await _prune();
    await BackupCodec.restore(_db, data);
  }
}
