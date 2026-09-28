# Tide — Milestone 3 (Reflection: check-ins, Journal, daily note) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the reflective half of the app, which is three features.
- **Check-in card on Today.** Before 17:00 it's an Intention card; from 17:00 it's a Reflection card with the morning intention, a mood picker and a note. Both save automatically.
- **Journal tab.** A month calendar of mood dots, plus a calm scroll of past check-ins. Past days can be opened and edited.
- **Daily note.** One line under the greeting. It resurfaces your own reflection from about a month, three months or a year ago, or shows a gentle line written for the app.

**Architecture:**
- **New repository:** `CheckInRepository` over the existing `check_ins` table. There are no schema changes.
- **`AutosaveField`:** a shared widget that saves 600 ms after typing stops. It flushes any pending save when it's disposed, so nothing typed is lost when you leave the screen.
- **`pickDailyNote`:** a pure function that chooses the daily note, fed by a `FutureProvider` keyed on `todayKeyProvider`.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, go_router 18, drift 2.35 and intl. No new packages.

**Spec:** `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`, §2.1, §2.3, §4.4 and §4.6.

**Depends on:** Milestone 2, which provides `todayKeyProvider`, `TideCard`, `AsyncListX.listOrEmpty`, `pumpHarness` and the `seed:` option on `pumpTideApp`.

## Global Constraints

- Every Milestone 1 and Milestone 2 constraint still holds:
  - `Clock` is the only source of "now".
  - Timestamps are written in UTC and read back with `.toLocal()`.
  - Dates are `yyyy-MM-dd` strings.
  - Screens use providers, providers use repositories, and only repositories touch drift.
  - The time-of-day enum is `PartOfDay`.
  - Snackbars that have an action set `persist: false`.
  - Every duration goes through `motion()`.
- The check-in card switches at **17:00 local**, using the hour from `nowProvider`. Before 17:00 it shows Intention; from 17:00 it shows Reflection.
- Autosave uses a **600 ms debounce**. The subtle "Saved" label shows for 1.5 s. A failed save shows "Couldn't save that. Try again" and keeps the text.
- Mood is **1–5 or empty**. There are no mood numbers in the UI, only colours from `TideColors.mood`.
- Daily note:
  - Check the resurfacing windows in the order 30 days, then 90, then 365, each with a ±2 day tolerance.
  - Truncate the resurfaced text to about 100 characters at a word boundary, ending with "…".
  - Otherwise use a bundled line seeded by the date, so it stays the same all day.
- The bundled lines are **original writing**. No third-party quotes.
- Run `git push` after every commit.

## Review Focus

1. **Leaving a screen mid-sentence.** Say you navigate away 300 ms after typing, before the debounce fires. The text must still be saved. Covered in Task 3 (the dispose flush).
2. **Clearing a field to nothing.** The stored value becomes null, and a day with nothing left disappears from the Journal. It must not show up as a blank entry. Covered in Task 1.
3. **A reflection written at 23:50, with the app reopened at 00:10.** The next day's card is the Intention card (it's before 17:00), and yesterday's reflection is intact in the Journal. Covered in Task 4.
4. **Resurfaced text with line breaks or huge length.** Whitespace collapses to single spaces, and the text is truncated at a word boundary. It never cuts mid-word or exceeds the limit. Covered in Task 2.
5. **Tapping a future day in the calendar.** Nothing happens: you can't write tomorrow's check-in. Covered in Task 5.

---

## File map

```
lib/data/repositories/check_in_repository.dart   # CheckIn, CheckInRepository
lib/data/providers.dart                          # + checkInRepositoryProvider
lib/content/daily_lines.dart                     # dailyLines (60 original lines)
lib/features/today/daily_note.dart               # DailyNote, pickDailyNote, truncateWords, dailyNoteProvider, DailyNoteView
lib/ui/widgets/autosave_field.dart               # AutosaveField
lib/features/checkin/mood_picker.dart            # moodNames, MoodPicker
lib/features/checkin/providers.dart              # checkInForDayProvider, journalEntriesProvider, monthMoodsProvider
lib/features/checkin/check_in_card.dart          # CheckInCard
lib/features/checkin/check_in_editor_screen.dart # CheckInEditorScreen (past days)
lib/features/journal/month_calendar.dart         # MonthCalendar
lib/features/journal/journal_screen.dart         # JournalScreen (replaces the M1 placeholder)
lib/features/today/today_screen.dart             # + DailyNoteView, CheckInCard
lib/router.dart                                  # + /journal/:date
test/unit/check_in_repository_test.dart  test/unit/daily_note_test.dart
test/widget/autosave_field_test.dart     test/widget/mood_picker_test.dart
test/widget/check_in_card_test.dart      test/widget/journal_test.dart
test/widget/daily_note_view_test.dart
```

---

### Task 1: Check-in repository

**Files:**
- Create: `lib/data/repositories/check_in_repository.dart`, `test/unit/check_in_repository_test.dart`
- Modify: `lib/data/providers.dart`

**Interfaces:**
- Consumes: `AppDatabase.checkIns`, `CheckInsCompanion`, `CheckInRow` and `Clock`.
- Produces:
  - `class CheckIn`, with fields `date`, `intention?`, `mood?` and `reflection?`, plus the getter `isEmpty`.
  - `class CheckInRepository`, constructed as `CheckInRepository(AppDatabase, Clock, {Uuid? uuid})`, with these methods:
    - `Stream<CheckIn?> watchDay(String date)`
    - `Future<void> saveIntention(String date, String text)`
    - `Future<void> saveMood(String date, int? mood)`: throws `ArgumentError` unless the mood is null or 1–5.
    - `Future<void> saveReflection(String date, String text)`
    - `Stream<List<CheckIn>> watchEntries()`: non-empty check-ins, newest first.
    - `Stream<Map<String, int?>> watchMonth(int year, int month)`: date → mood for non-empty days in that month.
    - `Future<Map<String, String>> reflectionsBetween(String from, String to)`: non-empty reflections, inclusive of both ends.
  - `checkInRepositoryProvider`
- Blank text (after trimming) is stored as `null`, so an emptied day disappears from the Journal. There is one row per date. Saving reuses that date's row if it exists; otherwise it inserts a new one.

- [ ] **Step 1: Write the failing test**

`test/unit/check_in_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late CheckInRepository repo;

  setUp(() {
    db = testDb();
    repo = CheckInRepository(db, FakeClock(DateTime(2026, 9, 28, 9)));
  });
  tearDown(() => db.close());

  test('saving parts of a day keeps one row per date', () async {
    await repo.saveIntention('2026-09-28', '  Be gentle ');
    await repo.saveMood('2026-09-28', 4);
    await repo.saveReflection('2026-09-28', 'A quiet, good day.');
    final rows = await db.select(db.checkIns).get();
    expect(rows, hasLength(1));
    final day = await repo.watchDay('2026-09-28').first;
    expect(day!.intention, 'Be gentle');
    expect(day.mood, 4);
    expect(day.reflection, 'A quiet, good day.');
  });

  test('blank text is stored as null and an emptied day leaves the journal', () async {
    await repo.saveIntention('2026-09-28', 'Walk');
    expect(await repo.watchEntries().first, hasLength(1));
    await repo.saveIntention('2026-09-28', '   ');
    final day = await repo.watchDay('2026-09-28').first;
    expect(day!.intention, isNull);
    expect(day.isEmpty, isTrue);
    expect(await repo.watchEntries().first, isEmpty);
  });

  test('mood accepts 1–5 or null only', () async {
    await repo.saveMood('2026-09-28', 5);
    await repo.saveMood('2026-09-28', null);
    expect((await repo.watchDay('2026-09-28').first)!.mood, isNull);
    expect(() => repo.saveMood('2026-09-28', 0), throwsArgumentError);
    expect(() => repo.saveMood('2026-09-28', 6), throwsArgumentError);
  });

  test('entries are newest first', () async {
    await repo.saveReflection('2026-09-20', 'older');
    await repo.saveReflection('2026-09-27', 'newer');
    expect((await repo.watchEntries().first).map((c) => c.date), ['2026-09-27', '2026-09-20']);
  });

  test('watchMonth maps days to moods within the month only', () async {
    await repo.saveMood('2026-08-31', 2);
    await repo.saveMood('2026-09-01', 3);
    await repo.saveReflection('2026-09-15', 'no mood');
    expect(await repo.watchMonth(2026, 9).first, {'2026-09-01': 3, '2026-09-15': null});
  });

  test('reflectionsBetween is inclusive and skips blanks', () async {
    await repo.saveReflection('2026-08-29', 'a month ago');
    await repo.saveReflection('2026-08-30', ' ');
    await repo.saveIntention('2026-08-31', 'intention only');
    expect(await repo.reflectionsBetween('2026-08-29', '2026-08-31'), {'2026-08-29': 'a month ago'});
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/check_in_repository_test.dart`
Expected: FAIL, because `check_in_repository.dart` is not found.

- [ ] **Step 3: Implement `lib/data/repositories/check_in_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';

class CheckIn {
  const CheckIn({required this.date, this.intention, this.mood, this.reflection});

  final String date;
  final String? intention;
  final int? mood;
  final String? reflection;

  bool get isEmpty => intention == null && mood == null && reflection == null;
}

class CheckInRepository {
  CheckInRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static String? _clean(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Stream<CheckIn?> watchDay(String date) =>
      (_db.select(_db.checkIns)..where((c) => c.date.equals(date) & c.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toCheckIn(r));

  Future<void> saveIntention(String date, String text) =>
      _upsert(date, CheckInsCompanion(intention: Value(_clean(text))));

  Future<void> saveReflection(String date, String text) =>
      _upsert(date, CheckInsCompanion(reflection: Value(_clean(text))));

  Future<void> saveMood(String date, int? mood) {
    if (mood != null && (mood < 1 || mood > 5)) {
      throw ArgumentError.value(mood, 'mood', 'must be 1–5 or null');
    }
    return _upsert(date, CheckInsCompanion(mood: Value(mood)));
  }

  Expression<bool> _notEmpty($CheckInsTable c) =>
      c.deletedAt.isNull() &
      (c.intention.isNotNull() | c.mood.isNotNull() | c.reflection.isNotNull());

  Stream<List<CheckIn>> watchEntries() {
    final q = _db.select(_db.checkIns)
      ..where(_notEmpty)
      ..orderBy([(c) => OrderingTerm.desc(c.date)]);
    return q.watch().map((rows) => rows.map(_toCheckIn).toList());
  }

  Stream<Map<String, int?>> watchMonth(int year, int month) {
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    final q = _db.select(_db.checkIns)..where((c) => _notEmpty(c) & c.date.like('$prefix%'));
    return q.watch().map((rows) => {for (final r in rows) r.date: r.mood});
  }

  Future<Map<String, String>> reflectionsBetween(String from, String to) async {
    final rows = await (_db.select(_db.checkIns)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.reflection.isNotNull() &
              c.date.isBiggerOrEqualValue(from) &
              c.date.isSmallerOrEqualValue(to)))
        .get();
    return {for (final r in rows) r.date: r.reflection!};
  }

  Future<void> _upsert(String date, CheckInsCompanion changes) => _db.transaction(() async {
        final now = _clock.now().toUtc();
        final existing = await (_db.select(_db.checkIns)..where((c) => c.date.equals(date)))
            .getSingleOrNull();
        if (existing == null) {
          await _db.into(_db.checkIns).insert(changes.copyWith(
                id: Value(_uuid.v4()),
                date: Value(date),
                createdAt: Value(now),
                updatedAt: Value(now),
              ));
        } else {
          await (_db.update(_db.checkIns)..where((c) => c.id.equals(existing.id)))
              .write(changes.copyWith(updatedAt: Value(now), deletedAt: const Value(null)));
        }
      });

  static CheckIn _toCheckIn(CheckInRow r) =>
      CheckIn(date: r.date, intention: r.intention, mood: r.mood, reflection: r.reflection);
}
```

Append to `lib/data/providers.dart`, and add `import 'repositories/check_in_repository.dart';`:

```dart
final checkInRepositoryProvider = Provider<CheckInRepository>(
  (ref) => CheckInRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `flutter test test/unit/check_in_repository_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/data test/unit/check_in_repository_test.dart
git commit -m "feat: add check-in repository"
git push
```

---

### Task 2: Daily note selection

**Files:**
- Create: `lib/content/daily_lines.dart`, `lib/features/today/daily_note.dart`, `test/unit/daily_note_test.dart`

**Interfaces:**
- Consumes: `dateKey`.
- Produces:
  - `const dailyLines`: a `List<String>` of 60 lines.
  - `enum NoteKind { resurfaced, line }` and `class DailyNote { String text; NoteKind kind; }`
  - `String truncateWords(String text, int max)`
  - `DailyNote pickDailyNote({required String today, required Map<String, String> reflections, List<String> lines = dailyLines})`
  - The provider and widget are added in Task 4.

- [ ] **Step 1: Write the failing test**

`test/unit/daily_note_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/content/daily_lines.dart';
import 'package:tide/features/today/daily_note.dart';

void main() {
  const today = '2026-09-28';

  test('60 original lines, all short and distinct', () {
    expect(dailyLines, hasLength(60));
    expect(dailyLines.toSet(), hasLength(60));
    expect(dailyLines.every((l) => l.length <= 80), isTrue);
  });

  test('resurfaces a reflection from exactly a month ago', () {
    final note = pickDailyNote(today: today, reflections: {'2026-08-29': 'Slow mornings suit me.'});
    expect(note.kind, NoteKind.resurfaced);
    expect(note.text, 'A month ago you wrote: “Slow mornings suit me.”');
  });

  test('allows ±2 days and prefers the exact day', () {
    expect(pickDailyNote(today: today, reflections: {'2026-08-31': 'two days off'}).text,
        contains('two days off'));
    expect(pickDailyNote(today: today, reflections: {'2026-09-01': 'three days off'}).kind,
        NoteKind.line);
    expect(
        pickDailyNote(today: today, reflections: {'2026-08-28': 'near', '2026-08-29': 'exact'}).text,
        contains('exact'));
  });

  test('checks a month, then three months, then a year', () {
    final all = {'2026-08-29': 'month', '2026-06-30': 'quarter', '2025-09-28': 'year'};
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('A month ago'));
    all.remove('2026-08-29');
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('Three months ago'));
    all.remove('2026-06-30');
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('A year ago'));
  });

  test('falls back to a bundled line that is stable within a day and varies across days', () {
    final a = pickDailyNote(today: today, reflections: {});
    final b = pickDailyNote(today: today, reflections: {});
    final next = pickDailyNote(today: '2026-09-29', reflections: {});
    expect(a.kind, NoteKind.line);
    expect(a.text, b.text);
    expect(next.text, isNot(a.text));
    expect(dailyLines, contains(a.text));
  });

  test('truncateWords collapses whitespace and cuts at a word boundary', () {
    expect(truncateWords('short', 100), 'short');
    expect(truncateWords('line one\n\n  line two', 100), 'line one line two');
    final long = List.filled(40, 'word').join(' ');
    final cut = truncateWords(long, 100);
    expect(cut.length, lessThanOrEqualTo(101));
    expect(cut, endsWith('word…'));
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/daily_note_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement `lib/content/daily_lines.dart`**

```dart
/// Original lines and gentle prompts written for Tide. One is shown per day
/// when there is no past reflection to resurface.
const dailyLines = <String>[
  'Small steps still count.',
  'What would make today feel lighter?',
  "You're allowed to go slowly.",
  'Notice one thing that went right.',
  'Rest is part of the plan.',
  'What can wait until tomorrow?',
  'Drink some water. Look out of a window.',
  "Be as patient with yourself as you'd be with a friend.",
  'One thing at a time is plenty.',
  'What are you looking forward to this week?',
  'A rough first try beats a perfect idea on hold.',
  'Who would you like to hear from today?',
  'A short walk can change a whole afternoon.',
  'What did you do well yesterday?',
  "It's fine to leave some things unfinished.",
  'Choose one thing to do with care.',
  'Breathe out a little longer than you breathe in.',
  "What's taking up space in your head? Capture it.",
  'Good days are often made of ordinary things.',
  'What would future you thank you for?',
  "You don't need to earn a break.",
  'Say no to one thing, kindly.',
  'What made you smile recently?',
  'Let the easy task be easy.',
  'Tidy one small corner.',
  'How are you, really?',
  'Progress hides in the quiet days too.',
  'What small kindness could you offer someone?',
  'Put the phone down for ten minutes.',
  'What would a calm version of today look like?',
  'Your pace is your pace.',
  'Leave a little room for surprise.',
  "What's one thing you're grateful for right now?",
  'Stretch. Your shoulders will thank you.',
  'Start with the part you understand.',
  'What are you carrying that you could set down?',
  'A plan is a guide, not a promise.',
  'Make something, however small.',
  'What did you learn this week?',
  'Eat something good, slowly.',
  "It's okay to ask for help.",
  'Which task would make the rest easier?',
  'Enough is a good amount.',
  'Step outside, even briefly.',
  'What does your body need today?',
  'Finish one thing before starting the next.',
  "Today doesn't have to be impressive.",
  "What's one thing you'd like to remember about today?",
  'Keep it simple. Then keep it going.',
  "Send the message you've been meaning to send.",
  'Some seasons are for sowing, not harvesting.',
  'What would you do if it only had to be good enough?',
  'Find one quiet minute and keep it.',
  'Let yesterday stay in yesterday.',
  "What's the next small step?",
  'Celebrate something tiny.',
  "You're further along than you think.",
  'Put on a song you love.',
  'What could you make easier for tomorrow?',
  'Go gently.',
];
```

- [ ] **Step 4: Implement `lib/features/today/daily_note.dart` (the selection part only)**

```dart
import '../../content/daily_lines.dart';
import '../../data/clock.dart';

enum NoteKind { resurfaced, line }

class DailyNote {
  const DailyNote({required this.text, required this.kind});

  final String text;
  final NoteKind kind;
}

/// Collapses whitespace and cuts at the last word boundary within [max] chars, adding "…".
String truncateWords(String text, int max) {
  final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (flat.length <= max) return flat;
  final cut = flat.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > 0 ? cut.substring(0, space) : cut).trimRight()}…';
}

const _windows = [
  (30, 'A month ago you wrote'),
  (90, 'Three months ago you wrote'),
  (365, 'A year ago you wrote'),
];
const _tolerance = [0, -1, 1, -2, 2];

/// Spec §4.6: resurface a past reflection (30 → 90 → 365 days, ±2), else a bundled line
/// seeded by the date.
DailyNote pickDailyNote({
  required String today,
  required Map<String, String> reflections,
  List<String> lines = dailyLines,
}) {
  final t = DateTime.parse(today);
  for (final (days, label) in _windows) {
    for (final offset in _tolerance) {
      final key = dateKey(DateTime(t.year, t.month, t.day - days + offset));
      final text = reflections[key]?.trim();
      if (text != null && text.isNotEmpty) {
        return DailyNote(
          text: '$label: “${truncateWords(text, 100)}”',
          kind: NoteKind.resurfaced,
        );
      }
    }
  }
  final seed = int.parse(today.replaceAll('-', ''));
  return DailyNote(text: lines[seed % lines.length], kind: NoteKind.line);
}
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `flutter test test/unit/daily_note_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/content lib/features/today/daily_note.dart test/unit/daily_note_test.dart
git commit -m "feat: add daily note selection and 60 original lines"
git push
```

---

### Task 3: Autosave field and mood picker

**Files:**
- Create: `lib/ui/widgets/autosave_field.dart`, `lib/features/checkin/mood_picker.dart`, `test/widget/autosave_field_test.dart`, `test/widget/mood_picker_test.dart`

**Interfaces:**
- Produces:
  - `AutosaveField({required String? initialValue, required Future<void> Function(String) onSave, required String hint, int minLines = 1, int maxLines = 1, TextStyle? style})`
    - It saves 600 ms after the last keystroke, and only when the trimmed text changed.
    - It flushes a pending save on dispose.
    - It shows "Saved" for 1.5 s after each save.
  - `const moodNames = ['Heavy', 'Low', 'Okay', 'Good', 'Bright']`
  - `MoodPicker({required int? value, required ValueChanged<int?> onChanged})`: keys are `ValueKey('mood-<1..5>')`. Tapping the selected mood clears it.

- [ ] **Step 1: Write the failing tests**

`test/widget/autosave_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/widgets/autosave_field.dart';

void main() {
  late List<String> saved;

  Future<void> pump(WidgetTester tester, {bool show = true, String? initial}) =>
      tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, PartOfDay.morning),
        home: Scaffold(
          body: show
              ? AutosaveField(
                  initialValue: initial,
                  hint: 'What would make today good?',
                  onSave: (v) async => saved.add(v),
                )
              : const SizedBox(),
        ),
      ));

  setUp(() => saved = []);

  testWidgets('saves 600 ms after typing stops, not before', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Walk by the sea');
    await tester.pump(const Duration(milliseconds: 500));
    expect(saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    expect(saved, ['Walk by the sea']);
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('saved-label'))).opacity, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('saved-label'))).opacity, 0);
  });

  testWidgets('leaving before the debounce still saves', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Half a thought');
    await tester.pump(const Duration(milliseconds: 300));
    await pump(tester, show: false);
    expect(saved, ['Half a thought']);
  });

  testWidgets('does not re-save unchanged text', (tester) async {
    await pump(tester, initial: 'Same');
    await tester.enterText(find.byType(TextField), 'Same ');
    await tester.pump(const Duration(milliseconds: 700));
    expect(saved, isEmpty);
  });

  testWidgets('a failed save shows a calm error and keeps the text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Scaffold(
        body: AutosaveField(
          initialValue: null,
          hint: 'hint',
          onSave: (v) async => throw Exception('disk full'),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Keep me');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text("Couldn't save that. Try again"), findsOneWidget);
    expect(find.text('Keep me'), findsOneWidget);
  });
}
```

`test/widget/mood_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/checkin/mood_picker.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';

void main() {
  testWidgets('selects a mood and clears it on a second tap', (tester) async {
    int? value;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.evening),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) =>
              MoodPicker(value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('mood-4')));
    await tester.pumpAndSettle();
    expect(value, 4);
    await tester.tap(find.byKey(const ValueKey('mood-4')));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(find.byTooltip('Good'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/widget/autosave_field_test.dart test/widget/mood_picker_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement `lib/ui/widgets/autosave_field.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tide_colors.dart';
import '../typography.dart';

/// Borderless text that saves itself 600 ms after typing stops (spec §4.4).
class AutosaveField extends StatefulWidget {
  const AutosaveField({
    super.key,
    required this.initialValue,
    required this.onSave,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.style,
  });

  final String? initialValue;
  final Future<void> Function(String value) onSave;
  final String hint;
  final int minLines;
  final int maxLines;
  final TextStyle? style;

  @override
  State<AutosaveField> createState() => _AutosaveFieldState();
}

class _AutosaveFieldState extends State<AutosaveField> {
  static const _debounceDelay = Duration(milliseconds: 600);

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  late String _lastSaved = (widget.initialValue ?? '').trim();
  Timer? _debounce;
  Timer? _savedTimer;
  bool _showSaved = false;
  String? _error;

  void _changed(String _) {
    if (_error != null) setState(() => _error = null);
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _flush);
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    _debounce = null;
    final value = _controller.text;
    if (value.trim() == _lastSaved) return;
    _lastSaved = value.trim();
    try {
      await widget.onSave(value);
      if (!mounted) return;
      setState(() => _showSaved = true);
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showSaved = false);
      });
    } catch (_) {
      _lastSaved = '\u0000'; // force a retry on the next change
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final value = _controller.text;
      if (value.trim() != _lastSaved) widget.onSave(value);
    }
    _savedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: widget.style ?? TideType.body(c.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: false,
            border: InputBorder.none,
            isCollapsed: true,
            errorText: _error,
          ),
          onChanged: _changed,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            key: const ValueKey('saved-label'),
            opacity: _showSaved ? 1 : 0,
            duration: motion(context, Motion.quick),
            child: Text('Saved', style: TideType.label(c.muted)),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `lib/features/checkin/mood_picker.dart`**

```dart
import 'package:flutter/material.dart';

import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';

const moodNames = ['Heavy', 'Low', 'Okay', 'Good', 'Bright'];

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 5; i++)
          Tooltip(
            message: moodNames[i - 1],
            child: InkResponse(
              key: ValueKey('mood-$i'),
              radius: 26,
              onTap: () => onChanged(value == i ? null : i),
              child: AnimatedContainer(
                duration: motion(context, Motion.quick),
                curve: Motion.ease,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TideColors.mood[i - 1].withValues(alpha: value == i ? 1 : 0.35),
                  border: Border.all(
                    color: value == i ? c.ink.withValues(alpha: 0.5) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `flutter test test/widget/autosave_field_test.dart test/widget/mood_picker_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/ui/widgets/autosave_field.dart lib/features/checkin test/widget/autosave_field_test.dart test/widget/mood_picker_test.dart
git commit -m "feat: add autosave field and mood picker"
git push
```

---

### Task 4: Check-in card and daily note on Today

**Files:**
- Create: `lib/features/checkin/providers.dart`, `lib/features/checkin/check_in_card.dart`, `test/widget/check_in_card_test.dart`, `test/widget/daily_note_view_test.dart`
- Modify: `lib/features/today/daily_note.dart` (add the provider and the view), `lib/features/today/today_screen.dart`

**Interfaces:**
- Consumes: `checkInRepositoryProvider`, `todayKeyProvider`, `nowProvider`, `AutosaveField`, `MoodPicker`, `TideCard` and `pickDailyNote`.
- Produces:
  - `checkInForDayProvider`: a `StreamProvider.autoDispose.family<CheckIn?, String>`.
  - `dailyNoteProvider`: a `FutureProvider<DailyNote>`.
  - Widgets: `DailyNoteView` and `CheckInCard`.
- **Ruling:** spec §4.4 says a saved intention "shows as quiet text; tap to edit". `AutosaveField` is borderless and unfilled, so the saved text already reads as quiet text, and tapping it simply edits it. There's no separate read and edit mode to switch between.
- **Ruling:** the switch happens at 17:00 local, exactly as the spec says. After midnight, even at 00:30, a new day shows its Intention card.

- [ ] **Step 1: Write the failing tests**

`test/widget/check_in_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('morning shows the intention card and saves what you type', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Intention'), findsOneWidget);
    expect(find.text('What would make today good?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'An unhurried lunch');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.date, '2026-09-28');
    expect(row.intention, 'An unhurried lunch');
    await disposeTideApp(tester, db);
  });

  testWidgets('from 17:00 the reflection card shows the morning intention, mood and note',
      (tester) async {
    final db = await pumpTideApp(tester, clock: FakeClock(DateTime(2026, 9, 28, 17)),
        seed: (db, clock) async {
      await CheckInRepository(db, clock).saveIntention('2026-09-28', 'Be kind to myself');
    });
    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('This morning: Be kind to myself'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mood-4')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Quiet and good.');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.mood, 4);
    expect(row.reflection, 'Quiet and good.');
    await disposeTideApp(tester, db);
  });

  testWidgets('a late reflection is kept and the next day starts with an intention',
      (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 50));
    final db = await pumpTideApp(tester, clock: clock);
    await tester.enterText(find.byType(TextField), 'Long day, glad it is done.');
    await tester.pump(const Duration(milliseconds: 700));

    clock.set(DateTime(2026, 9, 29, 0, 10));
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    // the minute timer refreshes nowProvider
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();

    expect(find.text('Intention'), findsOneWidget);
    final row = (await tester.runAsync(() => db.select(db.checkIns).getSingle()))!;
    expect(row.date, '2026-09-28');
    expect(row.reflection, 'Long day, glad it is done.');
    await disposeTideApp(tester, db);
  });
}
```

`test/widget/daily_note_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/content/daily_lines.dart';
import 'package:tide/data/repositories/check_in_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('Today resurfaces a reflection from a month ago', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CheckInRepository(db, clock).saveReflection('2026-08-29', 'Slow mornings suit me.');
    });
    expect(find.text('A month ago you wrote: “Slow mornings suit me.”'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('otherwise shows one of the bundled lines', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text(dailyLines[20260928 % dailyLines.length]), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/widget/check_in_card_test.dart test/widget/daily_note_view_test.dart`
Expected: FAIL, because `Intention` is not found and the daily note isn't rendered.

- [ ] **Step 3: Implement `lib/features/checkin/providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/check_in_repository.dart';

final checkInForDayProvider = StreamProvider.autoDispose.family<CheckIn?, String>(
  (ref, date) => ref.watch(checkInRepositoryProvider).watchDay(date),
);

final journalEntriesProvider = StreamProvider<List<CheckIn>>(
  (ref) => ref.watch(checkInRepositoryProvider).watchEntries(),
);

/// Key: (year, month).
final monthMoodsProvider = StreamProvider.autoDispose.family<Map<String, int?>, (int, int)>(
  (ref, ym) => ref.watch(checkInRepositoryProvider).watchMonth(ym.$1, ym.$2),
);
```

- [ ] **Step 4: Implement `lib/features/checkin/check_in_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import 'mood_picker.dart';
import 'providers.dart';

/// Intention before 17:00, Reflection from 17:00 (spec §4.4).
class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key});

  static const reflectionHour = 17;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final evening = ref.watch(nowProvider).hour >= reflectionHour;
    final repo = ref.read(checkInRepositoryProvider);
    final checkIn = ref.watch(checkInForDayProvider(today));

    return switch (checkIn) {
      AsyncData(:final value) => evening
          ? TideCard(
              title: 'Reflection',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value?.intention != null) ...[
                    Text('This morning: ${value!.intention}', style: TideType.note(c.muted)),
                    const SizedBox(height: 12),
                  ],
                  MoodPicker(
                    value: value?.mood,
                    onChanged: (m) => repo.saveMood(today, m),
                  ),
                  const SizedBox(height: 12),
                  AutosaveField(
                    key: ValueKey('reflection-$today'),
                    initialValue: value?.reflection,
                    hint: 'How was today?',
                    minLines: 3,
                    maxLines: 6,
                    onSave: (v) => repo.saveReflection(today, v),
                  ),
                ],
              ),
            )
          : TideCard(
              title: 'Intention',
              child: AutosaveField(
                key: ValueKey('intention-$today'),
                initialValue: value?.intention,
                hint: 'What would make today good?',
                onSave: (v) => repo.saveIntention(today, v),
              ),
            ),
      _ => const SizedBox.shrink(),
    };
  }
}
```

- [ ] **Step 5: Add the daily note provider and view**

Append to `lib/features/today/daily_note.dart`, and add the imports `package:flutter/material.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `../../data/providers.dart`, `../../ui/motion.dart`, `../../ui/tide_colors.dart` and `../../ui/typography.dart`:

```dart
final dailyNoteProvider = FutureProvider<DailyNote>((ref) async {
  final today = ref.watch(todayKeyProvider);
  final t = DateTime.parse(today);
  final reflections = await ref.watch(checkInRepositoryProvider).reflectionsBetween(
        dateKey(DateTime(t.year, t.month, t.day - 367)),
        dateKey(DateTime(t.year, t.month, t.day - 28)),
      );
  return pickDailyNote(today: today, reflections: reflections);
});

class DailyNoteView extends ConsumerWidget {
  const DailyNoteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final note = ref.watch(dailyNoteProvider);
    return AnimatedSwitcher(
      duration: motion(context, Motion.quick),
      child: switch (note) {
        AsyncData(:final value) => Padding(
            key: ValueKey(value.text),
            padding: const EdgeInsets.only(top: 8),
            child: Text(value.text, style: TideType.note(c.muted)),
          ),
        _ => const SizedBox(height: 8),
      },
    );
  }
}
```

- [ ] **Step 6: Lay out Today in spec order**

In `lib/features/today/today_screen.dart`, add the imports `../checkin/check_in_card.dart` and `daily_note.dart`. The children become:

```dart
        children: [
          const TodayHeader(),
          const DailyNoteView(),
          const SizedBox(height: 24),
          const CheckInCard(),
          const SizedBox(height: 12),
          HabitsCard(onLongPress: (habit) => showHabitHistory(context, habit)),
          const SizedBox(height: 12),
          const TasksCard(trailing: LaterLink()),
          const SizedBox(height: 8),
          const InboxLine(),
        ],
```

- [ ] **Step 7: Fix earlier tests that assumed Today had no text field**

Today now always contains the check-in `TextField`. Update each of these tests so that it targets the capture sheet's field. The sheet shows the hint "Book a table for Friday", so match on that hint:
- `test/widget/capture_test.dart` (every `enterText(find.byType(TextField), …)`)
- `test/widget/inbox_test.dart` (the `capture` helper)
- `test/widget/tasks_card_test.dart` (in the Add-task flow, target the editor's hint "Call the dentist")

Replace:

```dart
await tester.enterText(find.byType(TextField), X);
```

with:

```dart
await tester.enterText(find.widgetWithText(TextField, 'Book a table for Friday'), X);
```

or, for the task editor:

```dart
await tester.enterText(find.widgetWithText(TextField, 'Call the dentist'), X);
```

In `capture_test.dart`, the assertion `expect(find.byType(TextField), findsNothing)` becomes `expect(find.widgetWithText(TextField, 'Book a table for Friday'), findsNothing)`.

- [ ] **Step 8: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 9: Commit and push**

```bash
git add lib test
git commit -m "feat: add intention/reflection card and daily note to Today"
git push
```

---

### Task 5: Journal screen and mood calendar

**Files:**
- Create: `lib/features/journal/month_calendar.dart`, `test/widget/journal_test.dart`
- Modify: `lib/features/journal/journal_screen.dart` (full replacement)

**Interfaces:**
- Consumes: `journalEntriesProvider`, `monthMoodsProvider`, `todayKeyProvider` and `moodNames`.
- Produces:
  - `MonthCalendar({required int year, required int month, required Map<String, int?> moods, required String today, required ValueChanged<String> onDayTap, VoidCallback? onPrevious, VoidCallback? onNext})`
    - Day cells are keyed `ValueKey('cal-<date>')`.
    - Mood dots are keyed `ValueKey('dot-<date>-<mood>')`.
  - `JournalScreen`
- **Ruling (spec §2.3 covers days with an entry, but not days without one):**
  - Tapping a day that has an entry scrolls to it.
  - Tapping a past or current day with no entry opens that day's editor (Task 6), so a missed check-in can be filled in later.
  - Future days do nothing.

- [ ] **Step 1: Write the failing test**

`test/widget/journal_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/check_in_repository.dart';
import 'package:tide/features/journal/journal_screen.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

Future<void> _seed(AppDatabase db, FakeClock clock) async {
  final repo = CheckInRepository(db, clock);
  await repo.saveMood('2026-09-27', 4);
  await repo.saveReflection('2026-09-27', 'Quiet day by the sea.');
  await repo.saveIntention('2026-09-20', 'Call Nan');
}

void main() {
  testWidgets('shows the month with mood dots and entries newest first', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();

    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-09-27-4')), findsOneWidget);
    expect(find.text('Sunday, 27 Sep'), findsOneWidget);
    expect(find.text('Quiet day by the sea.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Sunday, 27 Sep')).dy,
        lessThan(tester.getTopLeft(find.text('Sunday, 20 Sep')).dy));
    await disposeTideApp(tester, db);
  });

  testWidgets('previous month and back; next is disabled on the current month', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);
    await disposeTideApp(tester, db);
  });

  testWidgets('future days do nothing', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-2026-09-30')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('Wednesday, 30 Sep'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('an empty journal invites the first check-in', (tester) async {
    final db = await pumpTideApp(tester);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Your check-ins will gather here, day by day.'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/journal_test.dart`
Expected: FAIL, because `September 2026` is not found.

- [ ] **Step 3: Implement `lib/features/journal/month_calendar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/clock.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.moods,
    required this.today,
    required this.onDayTap,
    this.onPrevious,
    this.onNext,
  });

  final int year;
  final int month;
  final Map<String, int?> moods;
  final String today;
  final ValueChanged<String> onDayTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final first = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: Text(DateFormat('MMMM y').format(first), style: TideType.title(c.ink)),
          ),
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final l in letters)
            Expanded(
              child: Text(l, textAlign: TextAlign.center, style: TideType.label(c.muted)),
            ),
        ]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.9,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              () {
                final key = dateKey(DateTime(year, month, d));
                final future = key.compareTo(today) > 0;
                final mood = moods[key];
                return InkResponse(
                  key: ValueKey('cal-$key'),
                  onTap: future ? null : () => onDayTap(key),
                  radius: 20,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$d',
                        style: TideType.label(future ? c.soft : c.ink).copyWith(
                          decoration: key == today ? TextDecoration.underline : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        key: mood == null ? null : ValueKey('dot-$key-$mood'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood == null
                              ? (moods.containsKey(key) ? c.soft : Colors.transparent)
                              : TideColors.mood[mood - 1],
                        ),
                      ),
                    ],
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Replace `lib/features/journal/journal_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/async_x.dart';
import '../../data/providers.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import '../checkin/mood_picker.dart';
import '../checkin/providers.dart';
import 'month_calendar.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late DateTime _month;
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowProvider);
    _month = DateTime(now.year, now.month);
  }

  void _onDayTap(String date, List<CheckIn> entries) {
    final key = _keys[date];
    if (entries.any((e) => e.date == date) && key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: motion(context, Motion.settle), curve: Motion.ease);
    } else {
      context.go('/journal/$date');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final now = ref.watch(nowProvider);
    final entries = ref.watch(journalEntriesProvider).listOrEmpty;
    final moods = switch (ref.watch(monthMoodsProvider((_month.year, _month.month)))) {
      AsyncData(:final value) => value,
      _ => const <String, int?>{},
    };
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Journal', style: TideType.title(c.ink)),
          const SizedBox(height: 16),
          TideCard(
            child: MonthCalendar(
              year: _month.year,
              month: _month.month,
              moods: moods,
              today: today,
              onDayTap: (d) => _onDayTap(d, entries),
              onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: isCurrentMonth
                  ? null
                  : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text('Your check-ins will gather here, day by day.', style: TideType.body(c.muted)),
          for (final e in entries)
            Padding(
              key: _keys.putIfAbsent(e.date, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: 12),
              child: _EntryCard(entry: e),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final CheckIn entry;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/journal/${entry.date}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(DateFormat('EEEE, d MMM').format(DateTime.parse(entry.date)),
                      style: TideType.label(c.muted)),
                ),
                if (entry.mood != null)
                  Tooltip(
                    message: moodNames[entry.mood! - 1],
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: TideColors.mood[entry.mood! - 1]),
                    ),
                  ),
              ]),
              if (entry.intention != null) ...[
                const SizedBox(height: 8),
                Text(entry.intention!, style: TideType.note(c.muted)),
              ],
              if (entry.reflection != null) ...[
                const SizedBox(height: 8),
                Text(entry.reflection!, style: TideType.body(c.ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

The M1 `shell_test` still finds `JournalScreen` by type, so it doesn't need changing.

- [ ] **Step 6: Commit and push**

```bash
git add lib/features/journal test/widget/journal_test.dart
git commit -m "feat: add journal with mood calendar and entries"
git push
```

---

### Task 6: Editing past days

**Files:**
- Create: `lib/features/checkin/check_in_editor_screen.dart`
- Modify: `lib/router.dart`, `test/widget/journal_test.dart`

**Interfaces:**
- Consumes: `checkInForDayProvider`, `checkInRepositoryProvider`, `AutosaveField`, `MoodPicker`, `calmPage` and `todayKeyProvider`.
- Produces:
  - `CheckInEditorScreen({required String date})`
  - The route `/journal/:date`. It rejects malformed or future dates with "That day isn't available."

- [ ] **Step 1: Write the failing tests**

Append inside `main()` in `test/widget/journal_test.dart`:

```dart
  testWidgets('opening an entry lets you edit that day', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiet day by the sea.'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, 27 Sep'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Quiet day by the sea.'), 'Quiet day by the sea. Swam.');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => (db.select(db.checkIns)
          ..where((c) => c.date.equals('2026-09-27')))
        .getSingle()))!;
    expect(row.reflection, 'Quiet day by the sea. Swam.');
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping an empty past day opens its editor', (tester) async {
    final db = await pumpTideApp(tester, seed: _seed);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cal-2026-09-25')));
    await tester.pumpAndSettle();
    expect(find.text('Friday, 25 Sep'), findsOneWidget);
    expect(find.text('How was the day?'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/widget/journal_test.dart`
Expected: the two new tests FAIL (no route matches `/journal/2026-09-27`).

- [ ] **Step 3: Implement `lib/features/checkin/check_in_editor_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import 'mood_picker.dart';
import 'providers.dart';

class CheckInEditorScreen extends ConsumerWidget {
  const CheckInEditorScreen({super.key, required this.date});

  final String date;

  static bool isValidDate(String date, String today) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
      DateTime.tryParse(date) != null &&
      date.compareTo(today) <= 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    if (!isValidDate(date, today)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text("That day isn't available.", style: TideType.body(c.muted))),
      );
    }
    final repo = ref.read(checkInRepositoryProvider);
    final checkIn = ref.watch(checkInForDayProvider(date));
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, d MMM').format(DateTime.parse(date)),
            style: TideType.title(c.ink)),
      ),
      body: switch (checkIn) {
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              TideCard(
                title: 'Intention',
                child: AutosaveField(
                  initialValue: value?.intention,
                  hint: 'What would have made it good?',
                  onSave: (v) => repo.saveIntention(date, v),
                ),
              ),
              const SizedBox(height: 12),
              TideCard(
                title: 'Reflection',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MoodPicker(value: value?.mood, onChanged: (m) => repo.saveMood(date, m)),
                  const SizedBox(height: 12),
                  AutosaveField(
                    initialValue: value?.reflection,
                    hint: 'How was the day?',
                    minLines: 4,
                    maxLines: 10,
                    onSave: (v) => repo.saveReflection(date, v),
                  ),
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

- [ ] **Step 4: Add the route**

In `lib/router.dart`, add `import 'features/checkin/check_in_editor_screen.dart';`, and replace the `/journal` GoRoute with:

```dart
              GoRoute(
                path: '/journal',
                builder: (context, state) => const JournalScreen(),
                routes: [
                  GoRoute(
                    path: ':date',
                    pageBuilder: (context, state) => calmPage(
                      state,
                      CheckInEditorScreen(date: state.pathParameters['date']!),
                    ),
                  ),
                ],
              ),
```

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib test/widget/journal_test.dart
git commit -m "feat: edit past check-ins from the journal"
git push
```

---

### Task 7: Device check

**Files:** none.

- [ ] **Step 1: Build and install**

```bash
flutter build apk --release
flutter install -d RFCX20G1V5B --release
```

- [ ] **Step 2: USER STEP — feel check with Jason**

- [ ] Morning: type an intention and watch "Saved" fade in and out.
- [ ] After 17:00: the Reflection card shows "This morning: …". Tap a mood, write a couple of lines, then leave the app straight away and reopen it. The text should still be there.
- [ ] Journal: the mood dot appears on today. Scroll back a month and return.
- [ ] Tap yesterday in the calendar and fill in a missed check-in.
- [ ] The daily note line reads nicely under the greeting (you'll only see a resurfaced one after a month of use).

- [ ] **Step 3: Record notes, then commit and push**

```bash
git add -A
git commit -m "docs: record Milestone 3 device check"
git push
```
