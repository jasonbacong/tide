import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/settings_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late SettingsRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = SettingsRepository(db, clock);
  });
  tearDown(() => db.close());

  test('starts empty with the system theme', () async {
    final s = await repo.read();
    expect(s.name, '');
    expect(s.theme, ThemePreference.system);
    expect(s.lastExportAt, isNull);
  });

  test('setName trims and ignores blanks', () async {
    await repo.setName('  Jason ');
    await repo.setName('   ');
    expect((await repo.read()).name, 'Jason');
  });

  test('theme and timestamps', () async {
    await repo.setTheme(ThemePreference.dark);
    await repo.markExported();
    clock.advance(const Duration(hours: 1));
    await repo.markAutoBackup();
    final s = await repo.watch().first;
    expect(s.theme, ThemePreference.dark);
    expect(s.lastExportAt, DateTime(2026, 9, 28, 9));
    expect(s.lastAutoBackupAt, DateTime(2026, 9, 28, 10));
  });
}
