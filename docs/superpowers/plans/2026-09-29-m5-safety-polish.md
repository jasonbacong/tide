# Tide — Milestone 5 (Safety and polish) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Tide safe to rely on every day and finish it properly.
- **Everyday setup:** a first-launch welcome, a Settings screen (name, habits, theme, backup, about), and the greeting using your name.
- **Keeping data safe:**
  - Export and import of all your data.
  - Automatic weekly backups, keeping the newest 4.
  - A copy of the database before any schema upgrade.
  - Clearing out old deleted items after 30 days.
  - A calm recovery screen if the database can't be opened.
- **Polish:** the motion pass, and fixes for the review points left over from Milestone 1.
- **Finish:** a properly signed release APK, moved onto the phone without losing any data.

**Architecture:**
- **Settings:** a `SettingsRepository` over the single `app_settings` row. `TideApp` watches it to decide between the welcome screen and the main app, and to choose the theme mode.
- **Backups:**
  - `BackupCodec` handles pure data: export, parse and restore. It uses drift's generated `toJson`/`fromJson` with ISO date strings, so UTC timestamps survive byte for byte.
  - `BackupService` handles files: auto-backup, pruning, listing, export files and restore with a safety copy.
  - The share sheet and file picker sit behind small providers, so tests can replace them.
- **Startup and recovery:** `main.dart` opens the database defensively and shows `RecoveryApp` if that fails. It then runs startup maintenance in the background.

**Tech Stack:** The same stack as before, plus `path_provider`, `share_plus` and `file_picker` (added in Task 5).

**Spec:** `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`, §2.6, §3.1 (theme override), §3.5, §4.7 and §6.

**Depends on:** Milestones 2–4. It uses `AutosaveField` (M3), `showHabitEditor` (M2), the `HabitRepository` methods, the `pumpTideApp(seed:)` option and the `find.widgetWithText(TextField, '<hint>')` test convention.

## Global Constraints

- Every earlier constraint still holds (`Clock`, UTC timestamps, the layer rules, `PartOfDay`, `persist: false` and `motion()`).
- **The database stays exactly where it is:** `getApplicationDocumentsDirectory()/tide.sqlite`, which is drift_flutter's default. This was verified in `drift_flutter-0.3.1/lib/src/connect.dart`. Moving it would orphan the data already on the phone.
- **Export file:** the name is `tide-backup-yyyy-MM-dd-HHmmss.tide.json`. It contains `{"app": "tide", "schemaVersion": 1, "exportedAt": <ISO UTC>, "tables": {…all 8 tables…}}`.
- **Import:** checks the whole file before touching anything, asks "This replaces everything in the app.", saves a safety copy of the current data first, and replaces everything in one transaction.
- **Automatic backups:** run on start when the last one is at least 7 days old, and keep the newest 4 in `<documents>/backups/`.
- **Pre-migration copy:** `VACUUM INTO <documents>/backups/pre-migration-v<old>.sqlite`, taken before the migration steps run.
- **Tombstones** older than 30 days are deleted on start.
- Error copy is calm and specific:
  - "That file isn't a Tide backup."
  - "This backup is from a newer version of Tide."
  - "Couldn't archive that. Try again"
- **Release signing:** Jason creates the keystore and types its passwords himself. Neither the passwords nor the keystore are ever committed.
- **Moving to the new signing key erases the app.** Android refuses to install an update signed with a different key, so the app has to be uninstalled first, which deletes its data. That must only ever happen after a confirmed export (see Task 11).
- Run `git push` after every commit.

## Review Focus

1. **Import of a file from a newer app version, or a truncated file.** It's rejected before any data changes, with a calm message. Covered in Task 4.
2. **A restore that fails halfway.** For example, a backup containing duplicate IDs. The existing data is untouched, because it all happens in one transaction. Covered in Task 4.
3. **The phone's clock jumping backwards** after an automatic backup (manual clock change or timezone travel). The next automatic backup isn't blocked forever: a last-backup time in the future counts as "due". Covered in Task 5.
4. **A fresh install that needs the old data back.** The welcome screen offers "Restore from a backup", so nobody has to invent a name just to reach Settings. Covered in Task 6.
5. **Clearing your name in Settings.** A blank name is ignored rather than saved. Otherwise the app would drop you back to the welcome screen. Covered in Task 3.

---

## File map

```
pubspec.yaml                                   # + path_provider, share_plus, file_picker
.gitignore                                     # + android/key.properties, *.jks, *.keystore
android/app/build.gradle.kts                   # release signing from key.properties
lib/app_info.dart                              # appVersion
lib/main.dart                                  # defensive open → RecoveryApp; startup tasks
lib/app.dart                                   # settings gating, theme mode, reduced-motion theme fade
lib/router.dart                                # + /settings; calmPage uses an exact 8 px rise
lib/data/repositories/settings_repository.dart # Settings, SettingsRepository
lib/data/db/app_database.dart                  # preMigrationDir, onUpgrade VACUUM INTO, databaseFile()
lib/data/backup/backup_codec.dart              # BackupData, BackupFormatException, BackupCodec
lib/data/backup/backup_service.dart            # BackupService, backupStamp()
lib/data/maintenance.dart                      # Maintenance.purgeTombstones, runStartupTasks
lib/data/providers.dart                        # + settingsRepositoryProvider, settingsProvider, backupServiceProvider
lib/features/onboarding/welcome_screen.dart    # WelcomeScreen
lib/features/settings/settings_screen.dart     # SettingsScreen
lib/features/settings/backup_section.dart      # BackupSection, exportAgeLabel, shareFileProvider, pickFileProvider
lib/features/recovery/recovery_app.dart        # RecoveryApp, RecoveryActions, DeviceRecoveryActions
lib/features/today/today_header.dart           # name + tap → settings
lib/features/today/today_screen.dart           # CalmEntry stagger
lib/ui/widgets/calm_entry.dart                 # CalmEntry
lib/features/capture/capture_sheet.dart        # ModalRoute guard
lib/features/capture/inbox_screen.dart         # archive failure message
lib/features/habits/providers.dart             # + activeHabitsProvider
test/support/pump_app.dart                     # + name, overrides
test/unit/settings_repository_test.dart  test/unit/backup_codec_test.dart  test/unit/backup_service_test.dart
test/unit/maintenance_test.dart          test/unit/export_age_label_test.dart
test/widget/welcome_test.dart  test/widget/settings_test.dart  test/widget/backup_section_test.dart
test/widget/recovery_test.dart test/widget/polish_test.dart
```

---

### Task 1: Settings repository

**Files:**
- Create: `lib/data/repositories/settings_repository.dart`, `test/unit/settings_repository_test.dart`
- Modify: `lib/data/providers.dart`

**Interfaces:**
- Produces:
  - `class Settings`, with fields `name`, `theme` (a `ThemePreference`), `lastExportAt?` and `lastAutoBackupAt?` (local).
  - `class SettingsRepository`, constructed as `SettingsRepository(AppDatabase, Clock)`, with these methods:
    - `Stream<Settings> watch()` and `Future<Settings> read()`
    - `Future<void> setName(String)`: a blank name is ignored.
    - `Future<void> setTheme(ThemePreference)`
    - `Future<void> markExported()` and `Future<void> markAutoBackup()`
  - Providers: `settingsRepositoryProvider` and `settingsProvider` (a `StreamProvider<Settings>`).

- [ ] **Step 1: Write the failing test**

`test/unit/settings_repository_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/settings_repository_test.dart`
Expected: FAIL, because `settings_repository.dart` is not found.

- [ ] **Step 3: Implement `lib/data/repositories/settings_repository.dart`**

```dart
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
```

Append to `lib/data/providers.dart`, and add `import 'repositories/settings_repository.dart';`:

```dart
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final settingsProvider =
    StreamProvider<Settings>((ref) => ref.watch(settingsRepositoryProvider).watch());
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `flutter test test/unit/settings_repository_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/data test/unit/settings_repository_test.dart
git commit -m "feat: add settings repository"
git push
```

---

### Task 2: Name in the greeting, theme preference and welcome gating

**Files:**
- Create: `lib/features/onboarding/welcome_screen.dart`, `test/widget/welcome_test.dart`
- Modify: `lib/app.dart`, `lib/features/today/today_header.dart`, `test/support/pump_app.dart`, `test/widget/shell_test.dart`, `test/widget/habits_card_test.dart`

**Interfaces:**
- Consumes: `settingsProvider`, `settingsRepositoryProvider` and `habitRepositoryProvider`.
- Produces:
  - `WelcomeScreen`
  - `TideApp` shows the welcome screen while the name is empty, and applies the chosen theme mode.
  - `pumpTideApp(tester, {FakeClock? clock, Seed? seed, String name = 'Jason', List<Override> overrides = const []})`
  - The greeting reads "Good morning, <name>".

- [ ] **Step 1: Update the test helper**

In `test/support/pump_app.dart`:
- Add the imports `package:flutter_riverpod/misc.dart` (it exports `Override` in Riverpod 3) and `package:tide/data/repositories/settings_repository.dart`.
- Change the signature to `Future<AppDatabase> pumpTideApp(WidgetTester tester, {FakeClock? clock, Seed? seed, String name = 'Jason', List<Override> overrides = const []})`.
- Replace the seed line with:

```dart
  await tester.runAsync(() async {
    if (name.isNotEmpty) await SettingsRepository(db, fake).setName(name);
    if (seed != null) await seed(db, fake);
  });
```

- Change the `overrides:` list to `[databaseProvider.overrideWithValue(db), clockProvider.overrideWithValue(fake), ...overrides]`.

- [ ] **Step 2: Update the greeting expectations and write the failing tests**

```bash
sed -i '' "s/find.text('Good morning')/find.text('Good morning, Jason')/g; s/find.text('Good evening')/find.text('Good evening, Jason')/g" test/widget/shell_test.dart test/widget/habits_card_test.dart
```

`test/widget/welcome_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/settings_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('first launch asks for a name before anything else', (tester) async {
    final db = await pumpTideApp(tester, name: '');
    expect(find.text('Welcome to Tide'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Type your first name'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('starting saves the name and any picked habits', (tester) async {
    final db = await pumpTideApp(tester, name: '');
    await tester.enterText(find.widgetWithText(TextField, 'Your first name'), 'Jason');
    await tester.tap(find.text('Drink water'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Good morning, Jason'), findsOneWidget);
    final habit = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(habit.name, 'Water');
    expect(habit.dailyTarget, 8);
    await disposeTideApp(tester, db);
  });

  testWidgets('the saved theme preference is applied', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await SettingsRepository(db, clock).setTheme(ThemePreference.dark);
    });
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run: `flutter test test/widget/welcome_test.dart test/widget/shell_test.dart`
Expected: FAIL. The welcome test can't find `Welcome to Tide`, and the shell test can't find `Good morning, Jason`.

- [ ] **Step 4: Implement `lib/features/onboarding/welcome_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../habits/habit_icons.dart';

/// Suggested starter habits (spec §2.6): label, name, icon, daily target.
const _suggestions = [
  ('Read', 'Read', 'book', 1),
  ('Drink water', 'Water', 'water', 8),
  ('Move', 'Move', 'run', 1),
];

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.footer});

  /// Extra action under Start. Task 6 adds "Restore from a backup" here.
  final Widget? footer;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  final _picked = <String>{};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Type your first name');
      return;
    }
    _saving = true;
    try {
      final habits = ref.read(habitRepositoryProvider);
      for (final (label, name, icon, target) in _suggestions) {
        if (_picked.contains(label)) await habits.add(name: name, icon: icon, dailyTarget: target);
      }
      // Name last: saving it switches the app from Welcome to Today.
      await ref.read(settingsRepositoryProvider).setName(_name.text);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          children: [
            Text('Welcome to Tide', style: TideType.greeting(c.ink)),
            const SizedBox(height: 8),
            Text('A calm place for your day.', style: TideType.body(c.muted)),
            const SizedBox(height: 40),
            Text('What should we call you?', style: TideType.label(c.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TideType.body(c.ink),
              decoration: InputDecoration(hintText: 'Your first name', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 28),
            Text('A few habits to start with (optional)', style: TideType.label(c.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (label, _, icon, _) in _suggestions)
                FilterChip(
                  avatar: Icon(iconFor(icon), size: 18),
                  label: Text(label),
                  selected: _picked.contains(label),
                  onSelected: (on) =>
                      setState(() => on ? _picked.add(label) : _picked.remove(label)),
                ),
            ]),
            const SizedBox(height: 40),
            FilledButton(onPressed: _start, child: const Text('Start')),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Gate `TideApp` on settings and apply the theme**

In `lib/app.dart`, add imports for `data/enums.dart`, `features/onboarding/welcome_screen.dart` and `ui/day_period.dart`. Then replace `build` with:

```dart
  ThemeMode _mode(ThemePreference p) => switch (p) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(dayPeriodProvider);
    final light = buildTheme(Brightness.light, period);
    final dark = buildTheme(Brightness.dark, period);
    final settings = ref.watch(settingsProvider);
    return switch (settings) {
      AsyncData(:final value) when value.name.isEmpty => MaterialApp(
          title: 'Tide',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: _mode(value.theme),
          home: const WelcomeScreen(),
        ),
      AsyncData(:final value) => MaterialApp.router(
          title: 'Tide',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: _mode(value.theme),
          themeAnimationDuration: Motion.crossfade,
          themeAnimationCurve: Motion.ease,
          routerConfig: _router,
        ),
      _ => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          home: const Scaffold(),
        ),
    };
  }
```

Remove the now-unused `ui/day_period.dart` import if the analyzer flags it.

- [ ] **Step 6: Use the name in the greeting**

In `lib/features/today/today_header.dart`:
- Add `final name = switch (ref.watch(settingsProvider)) { AsyncData(:final value) => value.name, _ => '' };`
- Replace `greetingFor(period, '')` with `greetingFor(period, name)`.
- Delete the "Milestone 5" comment.

- [ ] **Step 7: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 8: Commit and push**

```bash
git add lib test
git commit -m "feat: welcome screen, named greeting and theme preference"
git push
```

---

### Task 3: Tap the greeting to open Settings (name, habits, appearance, about)

**Files:**
- Create: `lib/app_info.dart`, `lib/features/settings/settings_screen.dart`, `test/widget/settings_test.dart`
- Modify: `lib/router.dart`, `lib/features/today/today_header.dart`, `lib/features/habits/providers.dart`

**Interfaces:**
- Consumes: `settingsProvider`, `settingsRepositoryProvider`, `AutosaveField`, `showHabitEditor`, `HabitRepository.reorder`, `iconFor` and `TideCard`.
- Produces:
  - `const appVersion = '1.0.0'`
  - `activeHabitsProvider`
  - `SettingsScreen({Widget? backupSection})`. Task 6 passes the Backup card in through `backupSection`.
  - The top-level route `/settings`, which sits outside the tab shell so there's no bottom bar.

- [ ] **Step 1: Write the failing test**

`test/widget/settings_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/settings/settings_screen.dart';

import '../support/pump_app.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Good morning, Jason'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the greeting opens settings without the tab bar', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('changing the name updates the greeting; a blank name is ignored', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    final field = find.widgetWithText(TextField, 'Jason');
    await tester.enterText(field, 'Jay');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(find.widgetWithText(TextField, 'Jay'), '   ');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Jay'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('theme can be set to dark', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await disposeTideApp(tester, db);
  });

  testWidgets('habits are listed and editable from settings', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await HabitRepository(db, clock).add(name: 'Water', icon: 'water', dailyTarget: 8);
    });
    await _openSettings(tester);
    expect(find.text('8 times a day'), findsOneWidget);
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.text('Edit habit'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('about says the data stays on the phone', (tester) async {
    final db = await pumpTideApp(tester);
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('Tide 1.0.0'), 200);
    expect(find.textContaining('stays on this phone'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/settings_test.dart`
Expected: FAIL, because `settings_screen.dart` is not found.

- [ ] **Step 3: Implement**

`lib/app_info.dart`:

```dart
const appVersion = '1.0.0';
```

Append to `lib/features/habits/providers.dart`:

```dart
final activeHabitsProvider =
    StreamProvider<List<Habit>>((ref) => ref.watch(habitRepositoryProvider).watchActive());
```

`lib/features/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_info.dart';
import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import '../habits/habit_editor_sheet.dart';
import '../habits/habit_icons.dart';
import '../habits/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.backupSection});

  final Widget? backupSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final settings = ref.watch(settingsProvider);
    final habits = ref.watch(activeHabitsProvider).listOrEmpty;
    final repo = ref.read(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: TideType.title(c.ink))),
      body: switch (settings) {
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            children: [
              TideCard(
                title: 'Name',
                child: AutosaveField(
                  initialValue: value.name,
                  hint: 'Your first name',
                  onSave: repo.setName,
                ),
              ),
              const SizedBox(height: 12),
              TideCard(
                title: 'Habits',
                trailing: TextButton(
                  onPressed: () => showHabitEditor(context),
                  child: const Text('Add habit'),
                ),
                child: habits.isEmpty
                    ? Text('No habits yet.', style: TideType.body(c.muted))
                    : ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final ids = [for (final h in habits) h.id];
                          ids.insert(newIndex, ids.removeAt(oldIndex));
                          ref.read(habitRepositoryProvider).reorder(ids);
                        },
                        children: [
                          for (final h in habits)
                            ListTile(
                              key: ValueKey(h.id),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(iconFor(h.icon), color: c.accent),
                              title: Text(h.name, style: TideType.body(c.ink)),
                              subtitle: Text(
                                h.dailyTarget == 1 ? 'Once a day' : '${h.dailyTarget} times a day',
                                style: TideType.label(c.muted),
                              ),
                              onTap: () => showHabitEditor(context, habit: h),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              TideCard(
                title: 'Appearance',
                child: SegmentedButton<ThemePreference>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemePreference.system, label: Text('System')),
                    ButtonSegment(value: ThemePreference.light, label: Text('Light')),
                    ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
                  ],
                  selected: {value.theme},
                  onSelectionChanged: (s) => repo.setTheme(s.first),
                ),
              ),
              if (backupSection != null) ...[const SizedBox(height: 12), backupSection!],
              const SizedBox(height: 12),
              TideCard(
                title: 'About',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tide $appVersion', style: TideType.body(c.ink)),
                  const SizedBox(height: 4),
                  Text('Everything stays on this phone unless you export it.',
                      style: TideType.label(c.muted)),
                ]),
              ),
            ],
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
```

- [ ] **Step 4: Add the route and make the greeting tappable**

In `lib/router.dart`, add `import 'features/settings/settings_screen.dart';`. Then add this top-level route after the `StatefulShellRoute.indexedStack(...)` entry inside `routes: [...]`:

```dart
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => calmPage(state, const SettingsScreen()),
        ),
```

In `lib/features/today/today_header.dart`, add `import 'package:go_router/go_router.dart';`, and wrap the greeting `Text` like this:

```dart
        Semantics(
          button: true,
          label: 'Open settings',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => context.push('/settings'),
            child: Text(greetingFor(period, name), style: TideType.greeting(c.ink)),
          ),
        ),
```

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib test/widget/settings_test.dart
git commit -m "feat: settings screen with name, habits, theme and about"
git push
```

---

### Task 4: Backup codec (export, parse, restore)

**Files:**
- Create: `lib/data/backup/backup_codec.dart`, `test/unit/backup_codec_test.dart`

**Interfaces:**
- Produces:
  - `class BackupFormatException implements Exception`, with a `message` field. Its two messages are `BackupFormatException.notTide` and `BackupFormatException.newer`.
  - `class BackupData`, with fields `exportedAt?`, `captures`, `tasks`, `habits`, `habitTicks`, `checkIns`, `goals`, `milestones` and `settings`. Each list field holds drift row objects.
  - `abstract final class BackupCodec`:
    - `schemaVersion = 1`
    - `Future<Map<String, Object?>> export(AppDatabase, DateTime nowUtc)`
    - `String encode(Map<String, Object?>)`
    - `BackupData parse(String source)`: throws `BackupFormatException`.
    - `Future<void> restore(AppDatabase, BackupData)`: runs in a single transaction and always leaves a settings row.

- [ ] **Step 1: Write the failing test**

`test/unit/backup_codec_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/backup_codec_test.dart`
Expected: FAIL, because `backup_codec.dart` is not found.

- [ ] **Step 3: Implement `lib/data/backup/backup_codec.dart`**

```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  static const notTide = "That file isn't a Tide backup.";
  static const newer = 'This backup is from a newer version of Tide.';

  final String message;

  @override
  String toString() => message;
}

class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.captures,
    required this.tasks,
    required this.habits,
    required this.habitTicks,
    required this.checkIns,
    required this.goals,
    required this.milestones,
    required this.settings,
  });

  final DateTime? exportedAt;
  final List<CaptureRow> captures;
  final List<TaskRow> tasks;
  final List<HabitRow> habits;
  final List<HabitTickRow> habitTicks;
  final List<CheckInRow> checkIns;
  final List<GoalRow> goals;
  final List<MilestoneRow> milestones;
  final List<SettingsRow> settings;
}

abstract final class BackupCodec {
  static const schemaVersion = 1;

  /// ISO strings keep UTC ("…Z") intact through the round trip.
  static const _serializer = ValueSerializer.defaults(serializeDateTimeValuesAsString: true);

  static Future<Map<String, Object?>> export(AppDatabase db, DateTime nowUtc) async {
    List<Map<String, dynamic>> rows(List<DataClass> list) =>
        [for (final r in list) r.toJson(serializer: _serializer)];
    return {
      'app': 'tide',
      'schemaVersion': schemaVersion,
      'exportedAt': nowUtc.toIso8601String(),
      'tables': {
        'captures': rows(await db.select(db.captures).get()),
        'tasks': rows(await db.select(db.tasks).get()),
        'habits': rows(await db.select(db.habits).get()),
        'habit_ticks': rows(await db.select(db.habitTicks).get()),
        'check_ins': rows(await db.select(db.checkIns).get()),
        'goals': rows(await db.select(db.goals).get()),
        'milestones': rows(await db.select(db.milestones).get()),
        'app_settings': rows(await db.select(db.appSettings).get()),
      },
    };
  }

  static String encode(Map<String, Object?> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  static BackupData parse(String source) {
    const notTide = BackupFormatException(BackupFormatException.notTide);
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw notTide;
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'tide') throw notTide;
    final version = decoded['schemaVersion'];
    if (version is! int) throw notTide;
    if (version > schemaVersion) throw const BackupFormatException(BackupFormatException.newer);
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) throw notTide;

    List<T> list<T>(
        String key, T Function(Map<String, dynamic> json, {ValueSerializer? serializer}) fromJson) {
      final raw = tables[key];
      if (raw is! List) throw notTide;
      try {
        return [
          for (final r in raw) fromJson((r as Map).cast<String, dynamic>(), serializer: _serializer),
        ];
      } catch (_) {
        throw notTide;
      }
    }

    return BackupData(
      exportedAt: DateTime.tryParse(decoded['exportedAt'] as String? ?? ''),
      captures: list('captures', CaptureRow.fromJson),
      tasks: list('tasks', TaskRow.fromJson),
      habits: list('habits', HabitRow.fromJson),
      habitTicks: list('habit_ticks', HabitTickRow.fromJson),
      checkIns: list('check_ins', CheckInRow.fromJson),
      goals: list('goals', GoalRow.fromJson),
      milestones: list('milestones', MilestoneRow.fromJson),
      settings: list('app_settings', SettingsRow.fromJson),
    );
  }

  /// Replaces everything in one transaction: any failure leaves the old data.
  static Future<void> restore(AppDatabase db, BackupData data) => db.transaction(() async {
        for (final table in db.allTables) {
          await db.delete(table).go();
        }
        await db.batch((b) {
          b.insertAll(db.captures, data.captures);
          b.insertAll(db.tasks, data.tasks);
          b.insertAll(db.habits, data.habits);
          b.insertAll(db.habitTicks, data.habitTicks);
          b.insertAll(db.checkIns, data.checkIns);
          b.insertAll(db.goals, data.goals);
          b.insertAll(db.milestones, data.milestones);
          b.insertAll(db.appSettings, data.settings);
        });
        if (data.settings.isEmpty) {
          await db.into(db.appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        }
      });
}
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `flutter test test/unit/backup_codec_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

If the round-trip test fails only on a `DateTime` column, compare the two dumps' values for that column. A `Z` versus `+00:00` difference means the serializer isn't being applied, so check that `_serializer` is passed to both `toJson` and `fromJson`.

- [ ] **Step 5: Commit and push**

```bash
git add lib/data/backup test/unit/backup_codec_test.dart
git commit -m "feat: add backup codec with validation and atomic restore"
git push
```

---

### Task 5: Backup service (files)

**Files:**
- Modify: `pubspec.yaml` (add the packages), `lib/data/providers.dart`
- Create: `lib/data/backup/backup_service.dart`, `test/unit/backup_service_test.dart`

**Interfaces:**
- Consumes: `BackupCodec`, `SettingsRepository` and `Clock`.
- Produces:
  - `String backupStamp(File file)`: extracts `yyyy-MM-dd-HHmmss` from the file name, or returns `''`.
  - `class BackupService`, constructed as `BackupService({required AppDatabase db, required Clock clock, required SettingsRepository settings, required Future<Directory> Function() backupsDir, required Future<Directory> Function() exportDir})`, with these members:
    - `static const keep = 4` and `static const interval = Duration(days: 7)`
    - `Future<File?> autoBackupIfDue()`
    - `Future<List<File>> listBackups()`: newest first.
    - `Future<File> exportFile()`
    - `Future<BackupData> read(File)`
    - `Future<void> restore(BackupData)`: writes a `before-restore-…` safety copy first.
  - `backupServiceProvider`

- [ ] **Step 1: Add the packages**

```bash
flutter pub add path_provider share_plus file_picker
```

- [ ] **Step 2: Write the failing test**

`test/unit/backup_service_test.dart`:

```dart
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
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `flutter test test/unit/backup_service_test.dart`
Expected: FAIL, because `backup_service.dart` is not found.

- [ ] **Step 4: Implement `lib/data/backup/backup_service.dart`**

```dart
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
  BackupService({
    required AppDatabase db,
    required Clock clock,
    required SettingsRepository settings,
    required Future<Directory> Function() backupsDir,
    required Future<Directory> Function() exportDir,
  })  : _db = db,
        _clock = clock,
        _settings = settings,
        _backupsDir = backupsDir,
        _exportDir = exportDir;

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
```

Append to `lib/data/providers.dart`, and add the imports `dart:io`, `package:path_provider/path_provider.dart` and `backup/backup_service.dart`:

```dart
final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      settings: ref.watch(settingsRepositoryProvider),
      backupsDir: () async => Directory('${(await getApplicationDocumentsDirectory()).path}/backups'),
      exportDir: getTemporaryDirectory,
    ));
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `flutter test test/unit/backup_service_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add pubspec.yaml pubspec.lock lib/data test/unit/backup_service_test.dart
git commit -m "feat: add backup service with weekly auto-backups and safe restore"
git push
```

---

### Task 6: Backup section in Settings, plus restore from the welcome screen

**Files:**
- Create: `lib/features/settings/backup_section.dart`, `test/unit/export_age_label_test.dart`, `test/widget/backup_section_test.dart`
- Modify: `lib/router.dart` (give `SettingsScreen` its backup section), `lib/app.dart` (the welcome footer)

**Interfaces:**
- Consumes: `backupServiceProvider`, `settingsProvider`, `settingsRepositoryProvider` and `backupStamp`.
- Produces:
  - `String exportAgeLabel(DateTime? last, DateTime now)`
  - Providers that tests can override:
    - `shareFileProvider`: a `Provider<Future<void> Function(File)>`.
    - `pickFileProvider`: a `Provider<Future<File?> Function()>`.
    - `backupFilesProvider`: a `FutureProvider.autoDispose<List<File>>`.
  - Widgets:
    - `BackupSection`
    - `RestoreFromBackupButton`, which is used on the welcome screen.
- **Ruling:** `markExported` is recorded as soon as the share sheet returns without an error. Android doesn't reliably report whether the file was actually saved, so this "Last exported" date might be optimistic.

- [ ] **Step 1: Write the failing tests**

`test/unit/export_age_label_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/settings/backup_section.dart';

void main() {
  final now = DateTime(2026, 9, 28, 9);
  test('labels', () {
    expect(exportAgeLabel(null, now), 'Not exported yet');
    expect(exportAgeLabel(DateTime(2026, 9, 28, 8), now), 'Last exported today');
    expect(exportAgeLabel(DateTime(2026, 9, 27, 23), now), 'Last exported yesterday');
    expect(exportAgeLabel(DateTime(2026, 8, 19), now), 'Last exported 40 days ago');
  });
}
```

`test/widget/backup_section_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/backup/backup_codec.dart';
import 'package:tide/data/providers.dart';
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
    await tester.scrollUntilVisible(find.text('Export'), 200);
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
```

In `test/support/pump_app.dart`, add this helper (and add the imports `dart:io`, `package:tide/data/backup/backup_service.dart` and `package:tide/data/repositories/settings_repository.dart` if they aren't already there):

```dart
/// Points backups and exports at a temp directory for widget tests.
Override backupDirsOverride(Directory tmp) => backupServiceProvider.overrideWith((ref) => BackupService(
      db: ref.watch(databaseProvider),
      clock: ref.watch(clockProvider),
      settings: ref.watch(settingsRepositoryProvider),
      backupsDir: () async => Directory('${tmp.path}/backups'),
      exportDir: () async => Directory('${tmp.path}/export'),
    ));
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/unit/export_age_label_test.dart test/widget/backup_section_test.dart`
Expected: FAIL, because `backup_section.dart` is not found.

- [ ] **Step 3: Implement `lib/features/settings/backup_section.dart`**

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_service.dart';
import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';

String exportAgeLabel(DateTime? last, DateTime now) {
  if (last == null) return 'Not exported yet';
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(last.year, last.month, last.day))
      .inDays;
  if (days <= 0) return 'Last exported today';
  if (days == 1) return 'Last exported yesterday';
  return 'Last exported $days days ago';
}

final shareFileProvider = Provider<Future<void> Function(File)>((ref) => (file) async {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Tide backup',
      ));
    });

final pickFileProvider = Provider<Future<File?> Function()>((ref) => () async {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = result?.files.single.path;
      return path == null ? null : File(path);
    });

final backupFilesProvider =
    FutureProvider.autoDispose<List<File>>((ref) => ref.watch(backupServiceProvider).listBackups());

/// Shared import flow: read → confirm → restore. Used by Settings and the welcome screen.
Future<void> importBackup(BuildContext context, WidgetRef ref, File? file) async {
  if (file == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  try {
    final data = await service.read(file);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace everything?'),
        content: const Text('This replaces everything in the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Replace')),
        ],
      ),
    );
    if (ok != true) return;
    await service.restore(data);
    // Restoring on the welcome screen swaps it for Today, so this context may be gone.
    if (context.mounted) ref.invalidate(backupFilesProvider);
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
    }
  } on BackupFormatException catch (e) {
    if (messenger.mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't restore that. Try again")));
    }
  }
}

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(backupServiceProvider).exportFile();
      await ref.read(shareFileProvider)(file);
      await ref.read(settingsRepositoryProvider).markExported();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't export. Try again")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final now = ref.watch(nowProvider);
    final last = switch (ref.watch(settingsProvider)) {
      AsyncData(:final value) => value.lastExportAt,
      _ => null,
    };
    final files = switch (ref.watch(backupFilesProvider)) {
      AsyncData(:final value) => value,
      _ => const <File>[],
    };
    return TideCard(
      title: 'Backup',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(exportAgeLabel(last, now), style: TideType.body(c.ink)),
        const SizedBox(height: 4),
        Text('Save a copy somewhere safe, like Google Drive. Automatic backups live on this phone '
            'and are lost if the app is uninstalled.', style: TideType.label(c.muted)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(onPressed: () => _export(context, ref), child: const Text('Export'))),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () async => importBackup(context, ref, await ref.read(pickFileProvider)()),
              child: const Text('Import'),
            ),
          ),
        ]),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Automatic backups', style: TideType.label(c.muted)),
          for (final f in files)
            Row(children: [
              Expanded(
                child: Text(
                  () {
                    final s = backupStamp(f);
                    final at = s.isEmpty
                        ? null
                        : DateFormat('yyyy-MM-dd-HHmmss').tryParse(s);
                    return at == null ? f.uri.pathSegments.last : DateFormat('EEE d MMM, HH:mm').format(at);
                  }(),
                  style: TideType.body(c.ink),
                ),
              ),
              TextButton(onPressed: () => importBackup(context, ref, f), child: const Text('Restore')),
            ]),
        ],
      ]),
    );
  }
}

class RestoreFromBackupButton extends ConsumerWidget {
  const RestoreFromBackupButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () async => importBackup(context, ref, await ref.read(pickFileProvider)()),
        child: const Text('Restore from a backup'),
      );
}
```

- [ ] **Step 4: Wire it in**

In `lib/router.dart`, add `import 'features/settings/backup_section.dart';` and change the settings page to `calmPage(state, const SettingsScreen(backupSection: BackupSection()))`.

In `lib/app.dart`, add `import 'features/settings/backup_section.dart';` and change `home: const WelcomeScreen()` to `home: const WelcomeScreen(footer: RestoreFromBackupButton())`.

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

If `SharePlus`/`ShareParams` are undefined because an older share_plus got resolved, use `await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], subject: 'Tide backup');` instead. If `DateFormat.tryParse` is missing, wrap `parse` in a try/catch instead.

- [ ] **Step 6: Commit and push**

```bash
git add lib test
git commit -m "feat: export, import and restore backups from settings and welcome"
git push
```

---

### Task 7: Startup maintenance and pre-migration copy

**Files:**
- Create: `lib/data/maintenance.dart`, `test/unit/maintenance_test.dart`
- Modify: `lib/data/db/app_database.dart`, `lib/main.dart`

**Interfaces:**
- Produces:
  - `class Maintenance`, constructed as `Maintenance(AppDatabase, Clock)`. Its method `Future<int> purgeTombstones({Duration olderThan = const Duration(days: 30)})` returns the number of rows deleted.
  - `Future<void> runStartupTasks({required Maintenance maintenance, required BackupService backups})`: never throws.
  - `AppDatabase(QueryExecutor, {Future<Directory?> Function()? preMigrationDir})`. On upgrade it runs `VACUUM INTO '<dir>/pre-migration-v<from>.sqlite'` before any migration step.
  - `static Future<File> AppDatabase.databaseFile()`, which returns `<documents>/tide.sqlite`.

- [ ] **Step 1: Write the failing test**

`test/unit/maintenance_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/maintenance_test.dart`
Expected: FAIL, because `maintenance.dart` is not found.

- [ ] **Step 3: Implement**

`lib/data/maintenance.dart`:

```dart
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
```

In `lib/data/db/app_database.dart`:
- Add the imports `dart:io` and `package:path_provider/path_provider.dart`.
- Change the constructor and factory, and add the helper and `onUpgrade`:

```dart
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.preMigrationDir});

  /// Where a copy of the database goes before any schema upgrade (spec §6).
  final Future<Directory?> Function()? preMigrationDir;

  static Future<Directory> _documents() => getApplicationDocumentsDirectory();

  /// drift_flutter's default location: `<documents>/tide.sqlite`. Must never change.
  static Future<File> databaseFile() async => File('${(await _documents()).path}/tide.sqlite');

  factory AppDatabase.open() => AppDatabase(
        driftDatabase(name: 'tide', native: const DriftNativeOptions(databaseDirectory: _documents)),
        preMigrationDir: () async => Directory('${(await _documents()).path}/backups'),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(AppSettingsCompanion.insert(id: const Value(1)));
        },
        onUpgrade: (m, from, to) async {
          final dir = await preMigrationDir?.call();
          if (dir != null) {
            await dir.create(recursive: true);
            final copy = File('${dir.path}/pre-migration-v$from.sqlite');
            if (await copy.exists()) await copy.delete();
            await customStatement("VACUUM INTO '${copy.path.replaceAll("'", "''")}'");
          }
          // Future schema steps go here, e.g. if (from < 2) { ... }
        },
      );
}
```

`const DriftNativeOptions(databaseDirectory: _documents)` needs `_documents` to be a static tear-off, which it is. If the analyzer rejects `const` there, drop the `const`.

If the upgrade test fails with "cannot VACUUM from within a transaction", replace the `customStatement` with a file copy of `tide.sqlite` plus any `-wal`/`-shm` siblings, using `File.copy`. drift 2.35 runs `onUpgrade` outside a transaction (confirmed in `db_base.dart`), so this isn't expected.

Replace `lib/main.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/clock.dart';
import 'data/db/app_database.dart';
import 'data/maintenance.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startTide();
}

/// Opens the database defensively; recovery (Task 8) hooks in here.
Future<void> startTide() async {
  final db = AppDatabase.open();
  await db.select(db.appSettings).get();
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
  runApp(UncontrolledProviderScope(container: container, child: const TideApp()));
  unawaited(runStartupTasks(
    maintenance: Maintenance(db, const SystemClock()),
    backups: container.read(backupServiceProvider),
  ));
}
```

- [ ] **Step 4: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib test/unit/maintenance_test.dart
git commit -m "feat: purge old tombstones, auto-backup on start, copy before migrations"
git push
```

---

### Task 8: Recovery screen when the database can't open

**Files:**
- Create: `lib/features/recovery/recovery_app.dart`, `test/widget/recovery_test.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces:
  - `abstract class RecoveryActions`, with the methods `Future<File?> latestBackup()`, `Future<File?> pickFile()` and `Future<void> resetWith(File backup)`. `resetWith` throws `BackupFormatException` for bad files.
  - `class DeviceRecoveryActions implements RecoveryActions`. It moves the broken `tide.sqlite` (and its `-wal`/`-shm` files) aside to `tide-broken-<stamp>.sqlite`, opens a fresh database, restores the backup and closes it.
  - `RecoveryApp({required RecoveryActions actions, required Future<void> Function() onRecovered})`

- [ ] **Step 1: Write the failing test**

`test/widget/recovery_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/recovery_test.dart`
Expected: FAIL, because `recovery_app.dart` is not found.

- [ ] **Step 3: Implement `lib/features/recovery/recovery_app.dart`**

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/backup/backup_codec.dart';
import '../../data/backup/backup_service.dart';
import '../../data/db/app_database.dart';
import '../../ui/day_period.dart';
import '../../ui/theme.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

abstract class RecoveryActions {
  Future<File?> latestBackup();
  Future<File?> pickFile();
  Future<void> resetWith(File backup);
}

class DeviceRecoveryActions implements RecoveryActions {
  Future<Directory> _backups() async =>
      Directory('${(await getApplicationDocumentsDirectory()).path}/backups');

  @override
  Future<File?> latestBackup() async {
    final dir = await _backups();
    if (!await dir.exists()) return null;
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.tide.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => backupStamp(b).compareTo(backupStamp(a)));
    return files.isEmpty ? null : files.first;
  }

  @override
  Future<File?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  @override
  Future<void> resetWith(File backup) async {
    final data = BackupCodec.parse(await backup.readAsString()); // validate before touching files
    final dbFile = await AppDatabase.databaseFile();
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('${dbFile.path}$suffix');
      if (await f.exists()) {
        await f.rename('${dbFile.parent.path}/tide-broken-$stamp.sqlite$suffix');
      }
    }
    final fresh = AppDatabase.open();
    try {
      await BackupCodec.restore(fresh, data);
    } finally {
      await fresh.close();
    }
  }
}

class RecoveryApp extends StatelessWidget {
  const RecoveryApp({super.key, required this.actions, required this.onRecovered});

  final RecoveryActions actions;
  final Future<void> Function() onRecovered;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, PartOfDay.afternoon),
        darkTheme: buildTheme(Brightness.dark, PartOfDay.afternoon),
        home: _RecoveryScreen(actions: actions, onRecovered: onRecovered),
      );
}

class _RecoveryScreen extends StatefulWidget {
  const _RecoveryScreen({required this.actions, required this.onRecovered});

  final RecoveryActions actions;
  final Future<void> Function() onRecovered;

  @override
  State<_RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<_RecoveryScreen> {
  File? _latest;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.actions.latestBackup().then((f) {
      if (mounted) setState(() => _latest = f);
    });
  }

  Future<void> _restore(File? file) async {
    if (file == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.actions.resetWith(file);
      await widget.onRecovered();
    } on BackupFormatException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't restore that. Try another file.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.healing_outlined, size: 40, color: c.accent),
              const SizedBox(height: 16),
              Text("Tide couldn't open your data",
                  textAlign: TextAlign.center, style: TideType.title(c.ink)),
              const SizedBox(height: 8),
              Text(
                'Your data is still on the phone. You can restore your latest backup or import '
                'a file you exported.',
                textAlign: TextAlign.center,
                style: TideType.body(c.muted),
              ),
              const SizedBox(height: 32),
              if (_latest != null)
                FilledButton(
                  onPressed: () => _restore(_latest),
                  child: const Text('Restore latest backup'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async => _restore(await widget.actions.pickFile()),
                child: const Text('Import a file'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TideType.body(c.warm)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Use it from `main.dart`**

In `lib/main.dart`, add `import 'features/recovery/recovery_app.dart';`, and replace the first two lines of `startTide()` with:

```dart
  final db = AppDatabase.open();
  try {
    await db.select(db.appSettings).get();
  } catch (_) {
    await db.close();
    runApp(RecoveryApp(actions: DeviceRecoveryActions(), onRecovered: startTide));
    return;
  }
```

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib test/widget/recovery_test.dart
git commit -m "feat: calm recovery screen when the database can't open"
git push
```

---

### Task 9: Motion pass and the Milestone 1 review leftovers

**Files:**
- Create: `lib/ui/widgets/calm_entry.dart`, `test/widget/polish_test.dart`
- Modify: `lib/features/today/today_screen.dart`, `lib/router.dart`, `lib/app.dart`, `lib/features/capture/capture_sheet.dart`, `lib/features/capture/inbox_screen.dart`

**Interfaces:**
- Produces: `CalmEntry({required int index, required Widget child})`. Each child fades in and rises 8 px over `Motion.quick`, delayed by `index × Motion.stagger`. It renders immediately when reduced motion is on.

This task closes these deferred review points from Milestone 1:
- Reduced motion for the theme cross-fade.
- An exact 8 px rise on page entry.
- The ModalRoute guard in the capture sheet.
- A message when archiving fails.
- An emoji/non-Latin capture test through the text field.

- [ ] **Step 1: Write the failing tests**

`test/widget/polish_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/clock.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/features/capture/inbox_screen.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/widgets/calm_entry.dart';

import '../support/pump_app.dart';

/// Holds every save until [gate] completes.
class _GatedCaptures extends CaptureRepository {
  _GatedCaptures(AppDatabase db, Clock clock, this.gate) : super(db, clock);
  final Completer<void> gate;

  @override
  Future<Capture?> add(String raw) async {
    await gate.future;
    return super.add(raw);
  }
}

class _BrokenArchive extends CaptureRepository {
  _BrokenArchive(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<void> archive(String id) async => throw Exception('disk');
}

Finder _entryOpacity() =>
    find.descendant(of: find.byType(CalmEntry), matching: find.byType(Opacity));

void main() {
  testWidgets('CalmEntry starts faded and settles in', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: const CalmEntry(index: 2, child: Text('card')),
    ));
    expect(tester.widget<Opacity>(_entryOpacity()).opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(_entryOpacity()).opacity, 1);
  });

  testWidgets('CalmEntry is instant with reduced motion', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const CalmEntry(index: 3, child: Text('card')),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.widget<Opacity>(_entryOpacity()).opacity, 1);
  });

  testWidgets('theme cross-fade drops to zero with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final db = await pumpTideApp(tester);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration,
        Duration.zero);
    await disposeTideApp(tester, db);
  });

  testWidgets('closing the sheet mid-save does not pop the screen underneath', (tester) async {
    final gate = Completer<void>();
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('existing');
    }, overrides: [
      captureRepositoryProvider.overrideWith((ref) =>
          _GatedCaptures(ref.watch(databaseProvider), ref.watch(clockProvider), gate)),
    ]);
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), 'Later idea');
    await tester.tap(find.text('Save to inbox'));
    await tester.pump();
    await tester.tapAt(const Offset(20, 20)); // dismiss the sheet while the save is pending
    await tester.pump(const Duration(milliseconds: 50)); // sheet is closing but still mounted
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(InboxScreen), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a failed archive puts the thought back and says so', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Stubborn');
    }, overrides: [
      captureRepositoryProvider.overrideWith(
          (ref) => _BrokenArchive(ref.watch(databaseProvider), ref.watch(clockProvider))),
    ]);
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Stubborn'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't archive that. Try again"), findsOneWidget);
    expect(find.text('Stubborn'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('emoji and other scripts survive the capture box exactly', (tester) async {
    const text = 'Swim 🌊 at Għajn Tuffieħa — 東京 مرحبا';
    final db = await pumpTideApp(tester);
    await tester.tap(find.byTooltip('Capture a thought'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), text);
    await tester.tap(find.text('Save to inbox'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.captures).getSingle()))!;
    expect(row.body, text);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail for the right reasons**

Run: `flutter test test/widget/polish_test.dart`
Expected:
- The CalmEntry tests FAIL, because `calm_entry.dart` is not found.
- After Step 3 adds that file, three tests still FAIL:
  - the theme cross-fade test (the duration is 600 ms, not zero);
  - the mid-save test (without the guard, `pop(true)` pops Inbox, so InboxScreen isn't found);
  - the archive test (no message appears, and the tile stays hidden).
- The emoji test may already pass. That's expected: it's regression coverage for code that already works, so note it and continue.

- [ ] **Step 3: Implement**

`lib/ui/widgets/calm_entry.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../motion.dart';

/// Fade in and rise 8 px, staggered by [index] (spec §3.5).
class CalmEntry extends StatefulWidget {
  const CalmEntry({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<CalmEntry> createState() => _CalmEntryState();
}

class _CalmEntryState extends State<CalmEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delay = Motion.stagger * widget.index;
    final total = motion(context, Motion.quick + delay);
    if (total == Duration.zero) {
      _c.value = 1;
      _t = const AlwaysStoppedAnimation(1);
      return;
    }
    _c.duration = total;
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Motion.ease));
    if (!_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, 8 * (1 - _t.value)), child: child),
        ),
        child: widget.child,
      );
}
```

In `lib/features/today/today_screen.dart`, wrap each card in `CalmEntry` with increasing indexes: `DailyNoteView` is 0, `CheckInCard` 1, `HabitsCard` 2, `TasksCard` 3 and `InboxLine` 4. For example: `CalmEntry(index: 1, child: CheckInCard())`. Keep the `SizedBox` spacers outside the wrappers.

In `lib/router.dart`, inside `calmPage`'s `transitionsBuilder`, replace the `SlideTransition(...)` with an exact 8 px rise:

```dart
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, 8 * (1 - curved.value)), child: child),
            child: child,
          ),
```

In `lib/app.dart`:
- Add `with WidgetsBindingObserver` to `_TideAppState`.
- In `initState`, call `WidgetsBinding.instance.addObserver(this);`.
- In `dispose`, call `WidgetsBinding.instance.removeObserver(this);`.
- Add:

```dart
  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  bool get _reduceMotion =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
```

- Then change `themeAnimationDuration: Motion.crossfade` to `themeAnimationDuration: _reduceMotion ? Duration.zero : Motion.crossfade`.

In `lib/features/capture/capture_sheet.dart`, change `if (mounted) Navigator.of(context).pop(true);` to:

```dart
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
```

In `lib/features/capture/inbox_screen.dart`, replace `await repo.archive(capture.id);` in `_archive` with:

```dart
    try {
      await repo.archive(capture.id);
    } catch (_) {
      if (mounted) setState(() => _hidden.remove(capture.id));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't archive that. Try again")));
      return;
    }
```

- [ ] **Step 4: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib test/widget/polish_test.dart
git commit -m "feat: staggered calm entry, reduced-motion theme fade, capture and archive safety"
git push
```

---

### Task 10: Release signing and moving the phone across without data loss

**Files:**
- Modify: `android/app/build.gradle.kts`, `.gitignore`

- [ ] **Step 1: Keep secrets out of git**

Append to `.gitignore`:

```gitignore
# Release signing (never commit)
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 2: Read signing values from `key.properties`**

In `android/app/build.gradle.kts`, add at the top of the file:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}
```

Inside `android { ... }`, add this before `buildTypes`:

```kotlin
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
```

In `buildTypes { release { ... } }`, replace the debug signing line with:

```kotlin
            signingConfig = if (keystoreProperties.isEmpty) signingConfigs.getByName("debug")
                            else signingConfigs.getByName("release")
```

Run `flutter build apk --release`. Expected: it builds, still signed with the debug key, because `key.properties` doesn't exist yet. Then commit and push:

```bash
git add .gitignore android/app/build.gradle.kts
git commit -m "build: release signing from untracked key.properties"
git push
```

- [ ] **Step 3: USER STEP — Jason creates the keystore**

The agent must not type, see or store these passwords. Jason runs this in his own terminal:

```bash
keytool -genkey -v -keystore ~/tide-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tide
```

Then he creates `android/key.properties` himself, with his own passwords:

```
storePassword=<his password>
keyPassword=<his password>
keyAlias=tide
storeFile=/Users/jasongrech/tide-upload.jks
```

He should keep `~/tide-upload.jks` and the passwords in his password manager. Losing them means future updates need another uninstall.

- [ ] **Step 4: USER STEP — back up before switching keys**

1. On the phone, open Tide, go to Settings, then Backup, and tap **Export**. Save the file to Google Drive.
2. Confirm the file appears in Drive.
3. Only then continue.

- [ ] **Step 5: Uninstall, reinstall, restore (confirm with Jason first)**

`adb uninstall` permanently deletes the app's data on the phone. Before running it, ask Jason: "Your backup from <date> is in Drive. OK to uninstall the old build?" Wait for a clear yes.

```bash
flutter build apk --release   # now signed with the real key from android/key.properties
~/Library/Android/sdk/platform-tools/adb uninstall com.jasongrech.tide
~/Library/Android/sdk/platform-tools/adb install build/app/outputs/flutter-apk/app-release.apk
```

(Updated after the M5 review: `flutter install` always uninstalls first, so every install and update
uses `adb install -r` instead. See README.)

On the phone: the welcome screen appears. Jason taps **Restore from a backup**, picks the Drive file, and taps **Replace**. Today should come back with his name, habits, tasks, goals and journal.

- [ ] **Step 6: USER STEP — final feel check**

- [ ] Tapping the greeting opens Settings. Name, habits, theme and backup all work.
- [ ] Export, then check that "Last exported today" shows.
- [ ] Cards drift in with a gentle stagger when opening Today, and page entries rise softly.
- [ ] Turn on Android's "Remove animations" setting and check that the app still feels fine, just without motion.
- [ ] Switch the theme to Light and Dark from Settings.

- [ ] **Step 7: Record notes, then commit and push**

```bash
git add -A
git commit -m "docs: record Milestone 5 device check"
git push
```
