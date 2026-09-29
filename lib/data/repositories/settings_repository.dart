import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Settings {
  const Settings({
    required this.name,
    required this.theme,
    this.lastExportAt,
    this.lastAutoBackupAt,
  });

  final String name;
  final ThemePreference theme;
  final DateTime? lastExportAt;
  final DateTime? lastAutoBackupAt;
}

class SettingsRepository {
  SettingsRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  SimpleSelectStatement<$AppSettingsTable, SettingsRow> get _row =>
      _db.select(_db.appSettings)..where((s) => s.id.equals(1));

  Stream<Settings> watch() => _row.watchSingle().map(_toSettings);

  Future<Settings> read() async => _toSettings(await _row.getSingle());

  Future<void> setName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _write(AppSettingsCompanion(name: Value(clean)));
  }

  Future<void> setTheme(ThemePreference theme) =>
      _write(AppSettingsCompanion(themeMode: Value(theme)));

  Future<void> markExported() =>
      _write(AppSettingsCompanion(lastExportAt: Value(_clock.now().toUtc())));

  Future<void> markAutoBackup() =>
      _write(AppSettingsCompanion(lastAutoBackupAt: Value(_clock.now().toUtc())));

  Future<void> _write(AppSettingsCompanion c) =>
      (_db.update(_db.appSettings)..where((s) => s.id.equals(1))).write(c);

  static Settings _toSettings(SettingsRow r) => Settings(
        name: r.name,
        theme: r.themeMode,
        lastExportAt: r.lastExportAt?.toLocal(),
        lastAutoBackupAt: r.lastAutoBackupAt?.toLocal(),
      );
}
