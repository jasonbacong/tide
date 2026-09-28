# Tide — Milestone 2 (Today core: tasks and habits) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today gains two cards and the Inbox gains one action.
- **Tasks card:**
  - add and edit tasks, with an optional energy tag, time estimate and date;
  - filter by energy or time;
  - complete a task with a calm fill-and-strike animation;
  - swipe to delete, with Undo;
  - long-press and drag to reorder;
  - a Later list for undated tasks.
- **Habits card:** circular habits that fill ring segments, bloom and ripple, with haptics; counts reset each day; long-press shows a 5-week history.
- **Inbox:** "Make task" turns a capture into a task.

**Architecture:** This builds on the Milestone 1 layers, which stay as they are: drift, then repositories, then Riverpod providers, then widgets.
- **New repositories:** `TaskRepository` and `HabitRepository`. They read and write the tables that already exist in schema v1, so **no migration is needed**.
- **"Today" in one place:** `todayKeyProvider` gives today's date. Every per-day query keys off it, so the day rolls over automatically at midnight or on resume.

**Tech Stack:** The same as Milestone 1: Flutter 3.47, flutter_riverpod 3, go_router 18 and drift 2.35. There are no new packages.

**Spec:** `docs/superpowers/specs/2026-09-28-personal-life-app-design.md`, §2.1, §2.4, §3.5, §4.1, §4.2 and §4.3.

## Global Constraints

- Every Milestone 1 constraint still holds:
  - `Clock` is the only source of "now".
  - Timestamps are written in **UTC** (`.toUtc()`) and read back with `.toLocal()`.
  - Dates are `yyyy-MM-dd` local strings.
  - Screens use providers, providers use repositories, and only repositories touch drift.
- Our time-of-day enum is **`PartOfDay`**, not `DayPeriod`. Material already has a `DayPeriod`.
- Snackbars that have an action must set `persist: false` and `duration: const Duration(seconds: 4)`.
- Every animation duration goes through `motion(context, …)`, so reduced-motion settings are respected.
- Tasks show no "overdue" labels and no red.
- Habits show no streak counters or numbers in their history. The only number shown is the live "3 of 8" caption.
- Soft limit of 8 active habits. Adding a ninth shows a gentle note but is allowed.
- All copy is sentence case. No "successfully" and no exclamation marks.
- Widget tests use `pumpTideApp` (the full app) or `pumpHarness` (a single widget). Both are torn down with `disposeTideApp`.
- Run `git push` after every commit.

## Review Focus

1. **A task finished at 23:59 must count as done that day.** It must not reappear as open, or as "done today", tomorrow. The UTC bounds for "that day" are computed in local time. Covered in Task 1.
2. **Filters that select nothing.** When no task matches, the card shows "Nothing matches. Try another filter." rather than an empty card. The filter resets the next day. Covered in Tasks 2 and 4.
3. **Changing a habit's target after ticking it.** For example, Water was at 8 of 8 and the target drops to 4. The habit counts as done, and the next tap resets it to 0. It never shows "9 of 4". Covered in Task 7.
4. **The day rolling over while the app is open.** Habit counts, "done today" tasks and the task filter all reset, and yesterday's open tasks roll forward. Covered in Tasks 1, 2 and 9.
5. **Deleting the last task, then tapping Undo.** The empty hint appears, then the task returns in its original place. Covered in Task 4.

---

## File map

```
lib/data/async_x.dart                         # AsyncValue<List<T>>.listOrEmpty
lib/data/providers.dart                       # + todayKeyProvider, taskRepositoryProvider, habitRepositoryProvider
lib/data/repositories/task_repository.dart    # Task, TaskRepository
lib/data/repositories/habit_repository.dart   # Habit, HabitToday, HabitRepository
lib/data/repositories/capture_repository.dart # + markConverted
lib/ui/theme.dart                             # + chipTheme
lib/ui/widgets/tide_card.dart                 # TideCard
lib/features/tasks/task_labels.dart           # taskMinuteOptions, energyLabel, minutesLabel, taskMeta
lib/features/tasks/task_filter.dart           # TaskFilter, filterTasks, taskFilterProvider
lib/features/tasks/providers.dart             # todayOpenTasksProvider, todayDoneTasksProvider, laterTasksProvider
lib/features/tasks/task_editor_sheet.dart     # showTaskEditor, TaskEditorSheet
lib/features/tasks/task_tile.dart             # TaskTile, StrikeText
lib/features/tasks/tasks_card.dart            # TasksCard
lib/features/tasks/later_screen.dart          # LaterScreen
lib/features/habits/habit_icons.dart          # habitIcons, iconFor
lib/features/habits/providers.dart            # todayHabitsProvider, habitHistoryProvider
lib/features/habits/habit_editor_sheet.dart   # showHabitEditor
lib/features/habits/habit_circle.dart         # HabitCircle
lib/features/habits/habits_card.dart          # HabitsCard
lib/features/habits/habit_history_sheet.dart  # weeksGrid, showHabitHistory
lib/features/today/today_screen.dart          # + HabitsCard, TasksCard
lib/features/capture/inbox_screen.dart        # tap → Make task
lib/router.dart                               # + /today/later
test/support/pump_app.dart                    # + seed callback
test/support/harness.dart                     # pumpHarness
test/unit/task_repository_test.dart  test/unit/task_filter_test.dart  test/unit/task_labels_test.dart
test/unit/habit_repository_test.dart test/unit/weeks_grid_test.dart
test/widget/task_editor_test.dart  test/widget/tasks_card_test.dart  test/widget/later_test.dart
test/widget/make_task_test.dart    test/widget/habit_editor_test.dart test/widget/habits_card_test.dart
test/widget/habit_history_test.dart
```

---

### Task 1: Task repository and today key

**Files:**
- Create: `lib/data/async_x.dart`, `lib/data/repositories/task_repository.dart`, `test/unit/task_repository_test.dart`
- Modify: `lib/data/providers.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `TasksCompanion`, `TaskRow` and `Energy` from M1; `Clock` and `dateKey`.
- Produces:
  - `class Task`, with fields `id`, `title`, `energy?`, `minutes?`, `date?`, `goalId?`, `completedAt?` (local), `createdAt` (local) and `sortOrder`, plus the getter `isDone`.
  - `class TaskRepository`, constructed as `TaskRepository(AppDatabase, Clock, {Uuid? uuid})`, with these methods:
    - `Future<Task?> add({required String title, Energy? energy, int? minutes, String? date, String? goalId})`: returns null if the title is blank.
    - `Future<void> update(String id, {required String title, Energy? energy, int? minutes, String? date, String? goalId})`
    - `Stream<List<Task>> watchTodayOpen(String today)`: open tasks with `date <= today`, ordered by `sortOrder` then `createdAt`.
    - `Stream<List<Task>> watchDoneOn(String day)`: tasks whose `completedAt` falls on that local day.
    - `Stream<List<Task>> watchLater()`: undated open tasks, oldest first.
    - `complete`, `uncomplete`, `delete` (tombstone), `restore` and `setDate(String id, String? date)`.
    - `reorder(List<String> ids)`
  - `extension AsyncListX<T> on AsyncValue<List<T>>`, with the getter `List<T> listOrEmpty`.
  - `todayKeyProvider`: a `Provider<String>` that returns `dateKey(now)`.
  - `taskRepositoryProvider`

- [ ] **Step 1: Write the failing test**

`test/unit/task_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = TaskRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<List<String>> open(String day) async =>
      (await repo.watchTodayOpen(day).first).map((t) => t.title).toList();
  Future<List<String>> done(String day) async =>
      (await repo.watchDoneOn(day).first).map((t) => t.title).toList();

  test('add trims and stores the optional tags', () async {
    final t = await repo.add(
        title: '  Call the dentist ', energy: Energy.low, minutes: 15, date: '2026-09-28');
    expect(t!.title, 'Call the dentist');
    expect(t.energy, Energy.low);
    expect(t.minutes, 15);
    expect(t.isDone, isFalse);
  });

  test('blank titles save nothing', () async {
    expect(await repo.add(title: '   '), isNull);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('today shows today and earlier, never future or undated', () async {
    await repo.add(title: 'yesterday', date: '2026-09-27');
    await repo.add(title: 'today', date: '2026-09-28');
    await repo.add(title: 'tomorrow', date: '2026-09-29');
    await repo.add(title: 'later');
    expect(await open('2026-09-28'), ['yesterday', 'today']);
  });

  test('completing moves a task from open to done for that day only', () async {
    final t = await repo.add(title: 'Water plants', date: '2026-09-28');
    clock.set(DateTime(2026, 9, 28, 23, 59));
    await repo.complete(t!.id);
    expect(await open('2026-09-28'), isEmpty);
    expect(await done('2026-09-28'), ['Water plants']);
    expect(await done('2026-09-29'), isEmpty);
    expect(await open('2026-09-29'), isEmpty);
  });

  test('uncomplete puts it back', () async {
    final t = await repo.add(title: 'Stretch', date: '2026-09-28');
    await repo.complete(t!.id);
    await repo.uncomplete(t.id);
    expect(await open('2026-09-28'), ['Stretch']);
    expect(await done('2026-09-28'), isEmpty);
  });

  test('later lists undated open tasks and setDate moves them to today', () async {
    final t = await repo.add(title: 'Sort photos');
    expect((await repo.watchLater().first).map((t) => t.title), ['Sort photos']);
    await repo.setDate(t!.id, '2026-09-28');
    expect(await repo.watchLater().first, isEmpty);
    expect(await open('2026-09-28'), ['Sort photos']);
  });

  test('delete hides and restore brings back', () async {
    final t = await repo.add(title: 'Pay rent', date: '2026-09-28');
    await repo.delete(t!.id);
    expect(await open('2026-09-28'), isEmpty);
    await repo.restore(t.id);
    expect(await open('2026-09-28'), ['Pay rent']);
  });

  test('new tasks go to the bottom and reorder rewrites the order', () async {
    final a = await repo.add(title: 'a', date: '2026-09-28');
    final b = await repo.add(title: 'b', date: '2026-09-28');
    final c = await repo.add(title: 'c', date: '2026-09-28');
    expect(await open('2026-09-28'), ['a', 'b', 'c']);
    await repo.reorder([c!.id, a!.id, b!.id]);
    expect(await open('2026-09-28'), ['c', 'a', 'b']);
  });

  test('update changes title, tags and date', () async {
    final t = await repo.add(title: 'Draft', date: '2026-09-28');
    await repo.update(t!.id, title: 'Final', energy: Energy.high, minutes: 60, date: null);
    expect(await open('2026-09-28'), isEmpty);
    final later = (await repo.watchLater().first).single;
    expect(later.title, 'Final');
    expect(later.energy, Energy.high);
    expect(later.minutes, 60);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/task_repository_test.dart`
Expected: FAIL, because `task_repository.dart` is not found.

- [ ] **Step 3: Implement `lib/data/repositories/task_repository.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.sortOrder,
    this.energy,
    this.minutes,
    this.date,
    this.goalId,
    this.completedAt,
  });

  final String id;
  final String title;
  final Energy? energy;
  final int? minutes;
  final String? date;
  final String? goalId;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int sortOrder;

  bool get isDone => completedAt != null;
}

class TaskRepository {
  TaskRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  DateTime _now() => _clock.now().toUtc();

  Future<Task?> add({
    required String title,
    Energy? energy,
    int? minutes,
    String? date,
    String? goalId,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return null;
    final now = _now();
    final id = _uuid.v4();
    await _db.into(_db.tasks).insert(TasksCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          title: clean,
          energy: Value(energy),
          minutes: Value(minutes),
          date: Value(date),
          goalId: Value(goalId),
          sortOrder: Value(await _nextSortOrder()),
        ));
    return _toTask(await (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingle());
  }

  Future<void> update(
    String id, {
    required String title,
    Energy? energy,
    int? minutes,
    String? date,
    String? goalId,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    await _write(
      id,
      TasksCompanion(
        title: Value(clean),
        energy: Value(energy),
        minutes: Value(minutes),
        date: Value(date),
        goalId: Value(goalId),
      ),
    );
  }

  Stream<List<Task>> watchTodayOpen(String today) {
    final q = _db.select(_db.tasks)
      ..where((t) =>
          t.deletedAt.isNull() & t.completedAt.isNull() & t.date.isSmallerOrEqualValue(today))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map(_toTasks);
  }

  Stream<List<Task>> watchDoneOn(String day) {
    final (start, end) = _utcBoundsOf(day);
    final q = _db.select(_db.tasks)
      ..where((t) =>
          t.deletedAt.isNull() &
          t.completedAt.isBiggerOrEqualValue(start) &
          t.completedAt.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]);
    return q.watch().map(_toTasks);
  }

  Stream<List<Task>> watchLater() {
    final q = _db.select(_db.tasks)
      ..where((t) => t.deletedAt.isNull() & t.completedAt.isNull() & t.date.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map(_toTasks);
  }

  Future<void> complete(String id) => _write(id, TasksCompanion(completedAt: Value(_now())));

  Future<void> uncomplete(String id) => _write(id, const TasksCompanion(completedAt: Value(null)));

  Future<void> delete(String id) => _write(id, TasksCompanion(deletedAt: Value(_now())));

  Future<void> restore(String id) => _write(id, const TasksCompanion(deletedAt: Value(null)));

  Future<void> setDate(String id, String? date) => _write(id, TasksCompanion(date: Value(date)));

  Future<void> reorder(List<String> ids) => _db.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await _write(ids[i], TasksCompanion(sortOrder: Value(i)));
        }
      });

  Future<void> _write(String id, TasksCompanion changes) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  Future<int> _nextSortOrder() async {
    final max = _db.tasks.sortOrder.max();
    final row = await (_db.selectOnly(_db.tasks)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  /// UTC instants bounding the local calendar day [day] (`yyyy-MM-dd`).
  static (DateTime, DateTime) _utcBoundsOf(String day) {
    final start = DateTime.parse(day); // no offset → local midnight
    final end = DateTime(start.year, start.month, start.day + 1);
    return (start.toUtc(), end.toUtc());
  }

  static List<Task> _toTasks(List<TaskRow> rows) => rows.map(_toTask).toList();

  static Task _toTask(TaskRow r) => Task(
        id: r.id,
        title: r.title,
        energy: r.energy,
        minutes: r.minutes,
        date: r.date,
        goalId: r.goalId,
        completedAt: r.completedAt?.toLocal(),
        createdAt: r.createdAt.toLocal(),
        sortOrder: r.sortOrder,
      );
}
```

- [ ] **Step 4: Add the providers and the async helper**

`lib/data/async_x.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncListX<T> on AsyncValue<List<T>> {
  /// The loaded list, or empty while loading or on error.
  List<T> get listOrEmpty => switch (this) {
        AsyncData(:final value) => value,
        _ => <T>[],
      };
}
```

Append to `lib/data/providers.dart`, and add `import 'repositories/task_repository.dart';` beside the other imports:

```dart
/// Today's local date key. Everything per-day watches this, so it rolls over at midnight.
final todayKeyProvider = Provider<String>((ref) => dateKey(ref.watch(nowProvider)));

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `flutter test test/unit/task_repository_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/data test/unit/task_repository_test.dart
git commit -m "feat: add task repository and today key"
git push
```

---

### Task 2: Task labels and filter

**Files:**
- Create: `lib/features/tasks/task_labels.dart`, `lib/features/tasks/task_filter.dart`, `test/unit/task_labels_test.dart`, `test/unit/task_filter_test.dart`

**Interfaces:**
- Consumes: `Task` and `todayKeyProvider` (from Task 1), and `Energy`.
- Produces:
  - Labels: `const taskMinuteOptions = [5, 15, 30, 60]`, `String energyLabel(Energy)`, `String minutesLabel(int)` and `String taskMeta(Task)`.
  - `class TaskFilter`, constructed as `TaskFilter({Energy? energy, int? maxMinutes})`, with `isEmpty` and `matches(Task)`.
  - `List<Task> filterTasks(List<Task>, TaskFilter)`
  - `taskFilterProvider`: a `NotifierProvider<TaskFilterNotifier, TaskFilter>`. Its notifier has `toggleEnergy(Energy)` and `toggleMaxMinutes(int)`.
- **Ruling (spec §4.2 is silent here):** while an energy or time filter is on, tasks with no energy or time tag are hidden. Choosing "Low" means you want to see tasks you have tagged low.

- [ ] **Step 1: Write the failing tests**

`test/unit/task_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_labels.dart';

Task _t({Energy? energy, int? minutes}) => Task(
    id: 'x', title: 'x', createdAt: DateTime(2026), sortOrder: 0, energy: energy, minutes: minutes);

void main() {
  test('labels', () {
    expect(energyLabel(Energy.medium), 'Medium');
    expect(minutesLabel(15), '15 min');
    expect(minutesLabel(60), '60+ min');
  });

  test('taskMeta joins what is set', () {
    expect(taskMeta(_t()), '');
    expect(taskMeta(_t(energy: Energy.low)), 'Low energy');
    expect(taskMeta(_t(energy: Energy.low, minutes: 15)), 'Low energy · 15 min');
    expect(taskMeta(_t(minutes: 60)), '60+ min');
  });
}
```

`test/unit/task_filter_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_filter.dart';

import '../support/fake_clock.dart';

Task _t(String title, {Energy? energy, int? minutes}) => Task(
    id: title, title: title, createdAt: DateTime(2026), sortOrder: 0, energy: energy, minutes: minutes);

void main() {
  final tasks = [
    _t('low15', energy: Energy.low, minutes: 15),
    _t('high60', energy: Energy.high, minutes: 60),
    _t('low30', energy: Energy.low, minutes: 30),
    _t('plain'),
  ];

  List<String> titles(TaskFilter f) => filterTasks(tasks, f).map((t) => t.title).toList();

  test('empty filter shows everything', () {
    expect(titles(const TaskFilter()), ['low15', 'high60', 'low30', 'plain']);
  });

  test('energy filter', () {
    expect(titles(const TaskFilter(energy: Energy.low)), ['low15', 'low30']);
  });

  test('time filter is inclusive and hides untagged', () {
    expect(titles(const TaskFilter(maxMinutes: 15)), ['low15']);
    expect(titles(const TaskFilter(maxMinutes: 30)), ['low15', 'low30']);
  });

  test('energy and time narrow together', () {
    expect(titles(const TaskFilter(energy: Energy.low, maxMinutes: 15)), ['low15']);
    expect(titles(const TaskFilter(energy: Energy.high, maxMinutes: 15)), isEmpty);
  });

  test('toggling the selected chip clears it, and the filter resets the next day', () {
    final clock = FakeClock(DateTime(2026, 9, 28, 20));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    addTearDown(container.dispose);
    final notifier = container.read(taskFilterProvider.notifier);

    notifier.toggleEnergy(Energy.low);
    notifier.toggleMaxMinutes(15);
    expect(container.read(taskFilterProvider).energy, Energy.low);
    notifier.toggleEnergy(Energy.low);
    expect(container.read(taskFilterProvider).energy, isNull);
    expect(container.read(taskFilterProvider).maxMinutes, 15);

    clock.set(DateTime(2026, 9, 29, 7));
    container.read(nowProvider.notifier).refresh();
    expect(container.read(taskFilterProvider).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/unit/task_labels_test.dart test/unit/task_filter_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement**

`lib/features/tasks/task_labels.dart`:

```dart
import '../../data/enums.dart';
import '../../data/repositories/task_repository.dart';

const taskMinuteOptions = [5, 15, 30, 60];

String energyLabel(Energy e) => switch (e) {
      Energy.low => 'Low',
      Energy.medium => 'Medium',
      Energy.high => 'High',
    };

String minutesLabel(int minutes) => minutes >= 60 ? '60+ min' : '$minutes min';

/// "Low energy · 15 min", or '' when the task has no tags.
String taskMeta(Task t) => [
      if (t.energy != null) '${energyLabel(t.energy!)} energy',
      if (t.minutes != null) minutesLabel(t.minutes!),
    ].join(' · ');
```

`lib/features/tasks/task_filter.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';

class TaskFilter {
  const TaskFilter({this.energy, this.maxMinutes});

  final Energy? energy;
  final int? maxMinutes;

  bool get isEmpty => energy == null && maxMinutes == null;

  /// Untagged tasks never match an active filter.
  bool matches(Task t) {
    if (energy != null && t.energy != energy) return false;
    if (maxMinutes != null && (t.minutes == null || t.minutes! > maxMinutes!)) return false;
    return true;
  }
}

List<Task> filterTasks(List<Task> tasks, TaskFilter filter) =>
    filter.isEmpty ? tasks : tasks.where(filter.matches).toList();

/// Rebuilds (and so resets) whenever the day changes.
class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() {
    ref.watch(todayKeyProvider);
    return const TaskFilter();
  }

  void toggleEnergy(Energy e) => state =
      TaskFilter(energy: state.energy == e ? null : e, maxMinutes: state.maxMinutes);

  void toggleMaxMinutes(int m) => state =
      TaskFilter(energy: state.energy, maxMinutes: state.maxMinutes == m ? null : m);
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `flutter test test/unit/task_labels_test.dart test/unit/task_filter_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/features/tasks test/unit/task_labels_test.dart test/unit/task_filter_test.dart
git commit -m "feat: add task labels and daily-resetting filter"
git push
```

---

### Task 3: Task editor sheet

**Files:**
- Create: `lib/features/tasks/providers.dart`, `lib/features/tasks/task_editor_sheet.dart`, `test/support/harness.dart`, `test/widget/task_editor_test.dart`
- Modify: `lib/ui/theme.dart` (add `chipTheme`), `test/support/pump_app.dart` (add a `seed` callback)

**Interfaces:**
- Consumes: `taskRepositoryProvider`, `todayKeyProvider`, `nowProvider`, `Task`, `task_labels.dart`, and `Motion` / `motion()`.
- Produces:
  - `Future<bool> showTaskEditor(BuildContext context, {Task? task, String? initialTitle})`: returns true once saved.
  - Stream providers: `todayOpenTasksProvider`, `todayDoneTasksProvider` and `laterTasksProvider` (each a `StreamProvider<List<Task>>`).
  - `Future<AppDatabase> pumpHarness(WidgetTester, WidgetBuilder, {FakeClock? clock})`
  - `pumpTideApp` gains an optional `Future<void> Function(AppDatabase db, FakeClock clock)? seed`.

- [ ] **Step 1: Extend the test helpers**

Replace `test/support/pump_app.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/app.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';

import 'fake_clock.dart';
import 'test_db.dart';

typedef Seed = Future<void> Function(AppDatabase db, FakeClock clock);

/// Pumps the full app on an in-memory database. Defaults to Monday 28 Sep 2026, 09:00.
/// [seed] runs against the database before the app starts.
Future<AppDatabase> pumpTideApp(WidgetTester tester, {FakeClock? clock, Seed? seed}) async {
  final db = testDb();
  final fake = clock ?? FakeClock(DateTime(2026, 9, 28, 9));
  if (seed != null) await tester.runAsync(() => seed(db, fake));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(fake),
    ],
    child: const TideApp(),
  ));
  await tester.pumpAndSettle();
  return db;
}

/// Tears the tree down first so providers cancel timers and streams, then closes the DB.
Future<void> disposeTideApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  // Drift cancels stream queries on a timer; let fake time run so it can finish.
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}
```

`test/support/harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';

import 'fake_clock.dart';
import 'test_db.dart';

/// Pumps a single widget (built by [builder]) inside the Tide theme and providers.
/// Dispose with disposeTideApp.
Future<AppDatabase> pumpHarness(WidgetTester tester, WidgetBuilder builder,
    {FakeClock? clock}) async {
  final db = testDb();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock ?? FakeClock(DateTime(2026, 9, 28, 9))),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Scaffold(body: Center(child: Builder(builder: builder))),
    ),
  ));
  await tester.pumpAndSettle();
  return db;
}
```

- [ ] **Step 2: Write the failing test**

`test/widget/task_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_editor_sheet.dart';

import '../support/harness.dart';
import '../support/pump_app.dart';

void main() {
  Widget opener(BuildContext context, {Task? task, String? initialTitle}) => TextButton(
        onPressed: () => showTaskEditor(context, task: task, initialTitle: initialTitle),
        child: const Text('Open'),
      );

  testWidgets('saves a task for today with energy and time', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Call the dentist');
    await tester.tap(find.text('Low'));
    await tester.tap(find.text('15 min'));
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.title, 'Call the dentist');
    expect(row.energy, Energy.low);
    expect(row.minutes, 15);
    expect(row.date, '2026-09-28');
    await disposeTideApp(tester, db);
  });

  testWidgets('blank title shows a gentle error', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name first'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.tasks).get()), isEmpty);
    await disposeTideApp(tester, db);
  });

  testWidgets('Later saves with no date', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sort photos');
    await tester.tap(find.text('Later'));
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.date, isNull);
    await disposeTideApp(tester, db);
  });

  testWidgets('Pick a date defaults to tomorrow', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Book flights');
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Tue, 29 Sep'), findsOneWidget);
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.date, '2026-09-29');
    await disposeTideApp(tester, db);
  });

  testWidgets('initialTitle prefills a new task', (tester) async {
    final db = await pumpHarness(tester, (c) => opener(c, initialTitle: 'From inbox'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('From inbox'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `flutter test test/widget/task_editor_test.dart`
Expected: FAIL, because `task_editor_sheet.dart` is not found.

- [ ] **Step 4: Add `chipTheme` to `lib/ui/theme.dart`**

Inside `ThemeData(...)`, after `bottomSheetTheme: ...`, add:

```dart
    chipTheme: ChipThemeData(
      backgroundColor: colors.background,
      selectedColor: colors.soft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      labelStyle: TextStyle(color: colors.ink, fontFamily: TideType.sans, fontSize: 13),
    ),
```

- [ ] **Step 5: Implement the task list providers**

`lib/features/tasks/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';

final todayOpenTasksProvider = StreamProvider<List<Task>>((ref) =>
    ref.watch(taskRepositoryProvider).watchTodayOpen(ref.watch(todayKeyProvider)));

final todayDoneTasksProvider = StreamProvider<List<Task>>((ref) =>
    ref.watch(taskRepositoryProvider).watchDoneOn(ref.watch(todayKeyProvider)));

final laterTasksProvider =
    StreamProvider<List<Task>>((ref) => ref.watch(taskRepositoryProvider).watchLater());
```

- [ ] **Step 6: Implement `lib/features/tasks/task_editor_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/clock.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'task_labels.dart';

Future<bool> showTaskEditor(BuildContext context, {Task? task, String? initialTitle}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, Motion.sheet),
      reverseDuration: motion(context, Motion.quick),
    ),
    builder: (_) => TaskEditorSheet(task: task, initialTitle: initialTitle),
  );
  return saved ?? false;
}

enum _When { today, later, date }

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, this.task, this.initialTitle});

  final Task? task;
  final String? initialTitle;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? widget.initialTitle ?? '');
  Energy? _energy;
  int? _minutes;
  _When _when = _When.today;
  String? _pickedDate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t == null) return;
    _energy = t.energy;
    _minutes = t.minutes;
    final today = ref.read(todayKeyProvider);
    if (t.date == null) {
      _when = _When.later;
    } else if (t.date == today) {
      _when = _When.today;
    } else {
      _when = _When.date;
      _pickedDate = t.date;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(nowProvider);
    final initial =
        _pickedDate != null ? DateTime.parse(_pickedDate!) : DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() {
        _when = _When.date;
        _pickedDate = dateKey(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name first');
      return;
    }
    _saving = true;
    final repo = ref.read(taskRepositoryProvider);
    final date = switch (_when) {
      _When.today => ref.read(todayKeyProvider),
      _When.later => null,
      _When.date => _pickedDate,
    };
    try {
      final existing = widget.task;
      if (existing == null) {
        await repo.add(title: _title.text, energy: _energy, minutes: _minutes, date: date);
      } else {
        await repo.update(existing.id,
            title: _title.text,
            energy: _energy,
            minutes: _minutes,
            date: date,
            goalId: existing.goalId);
      }
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text, style: TideType.label(c.muted)),
        );
    final dateChipLabel = _when == _When.date && _pickedDate != null
        ? DateFormat('EEE, d MMM').format(DateTime.parse(_pickedDate!))
        : 'Pick a date';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.task == null ? 'New task' : 'Edit task', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            autofocus: widget.task == null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Call the dentist', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          label('Energy'),
          Wrap(spacing: 8, children: [
            for (final e in Energy.values)
              ChoiceChip(
                label: Text(energyLabel(e)),
                selected: _energy == e,
                onSelected: (_) => setState(() => _energy = _energy == e ? null : e),
              ),
          ]),
          const SizedBox(height: 12),
          label('Time'),
          Wrap(spacing: 8, children: [
            for (final m in taskMinuteOptions)
              ChoiceChip(
                label: Text(minutesLabel(m)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = _minutes == m ? null : m),
              ),
          ]),
          const SizedBox(height: 12),
          label('When'),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: _when == _When.today,
              onSelected: (_) => setState(() => _when = _When.today),
            ),
            ChoiceChip(
              label: const Text('Later'),
              selected: _when == _When.later,
              onSelected: (_) => setState(() => _when = _When.later),
            ),
            ChoiceChip(
              label: Text(dateChipLabel),
              selected: _when == _When.date,
              onSelected: (_) => _pickDate(),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(widget.task == null ? 'Save task' : 'Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 8: Commit and push**

```bash
git add lib test
git commit -m "feat: add task editor sheet"
git push
```

---

### Task 4: Tasks card on Today

**Files:**
- Create: `lib/ui/widgets/tide_card.dart`, `lib/features/tasks/task_tile.dart`, `lib/features/tasks/tasks_card.dart`, `test/widget/tasks_card_test.dart`
- Modify: `lib/features/today/today_screen.dart`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `TideCard({String? title, Widget? trailing, required Widget child})`
  - `TaskTile({required Task task, required Future<void> Function() onToggle, required VoidCallback onOpen})`, whose check circle has the key `ValueKey('check-<id>')`.
  - `StrikeText(String text, {required double progress, required TextStyle style})`
  - `TasksCard`
- **Ruling (spec §3.5, the "row slides to the bottom" part):**
  - Completion plays the fill (350 ms) and then the strike (400 ms) inside the tile, and only then writes to the database.
  - The move to the finished section happens through an `AnimatedSize` over the whole card (`Motion.settle`, 450 ms), rather than a true shared-element slide.
  - This is a close approximation with far less code, and the Milestone 5 motion pass can revisit it.
- Reordering is only available while no filter is on. Otherwise a filtered list's positions wouldn't match the full order.

- [ ] **Step 1: Write the failing test**

`test/widget/tasks_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/tasks/task_tile.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('adding a task from Today shows it in the Tasks card', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text('Nothing planned. Add something small.'), findsOneWidget);
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call the dentist');
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Call the dentist'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('completing a task moves it below the open ones, struck through', (tester) async {
    late Task a;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = TaskRepository(db, clock);
      a = (await repo.add(title: 'First', date: '2026-09-28'))!;
      await repo.add(title: 'Second', date: '2026-09-28');
    });
    expect(tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Second')).dy));

    await tester.tap(find.byKey(ValueKey('check-${a.id}')));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('First')).dy,
        greaterThan(tester.getTopLeft(find.text('Second')).dy));
    final tile = tester.widget<TaskTile>(find.ancestor(
        of: find.text('First'), matching: find.byType(TaskTile)));
    expect(tile.task.isDone, isTrue);
    await disposeTideApp(tester, db);
  });

  testWidgets("yesterday's unfinished task rolls forward quietly", (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Reply to Sam', date: '2026-09-27');
    });
    expect(find.text('Reply to Sam'), findsOneWidget);
    expect(find.textContaining('overdue', findRichText: true), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('filters narrow by energy and time, and say when nothing matches', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = TaskRepository(db, clock);
      await repo.add(title: 'Easy call', energy: Energy.low, minutes: 15, date: '2026-09-28');
      await repo.add(title: 'Deep work', energy: Energy.high, minutes: 60, date: '2026-09-28');
      await repo.add(title: 'Untagged', date: '2026-09-28');
    });

    await tester.tap(find.text('Low'));
    await tester.pumpAndSettle();
    expect(find.text('Easy call'), findsOneWidget);
    expect(find.text('Deep work'), findsNothing);
    expect(find.text('Untagged'), findsNothing);

    await tester.tap(find.text('High'));
    await tester.tap(find.text('≤ 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches. Try another filter.'), findsOneWidget);

    await tester.tap(find.text('High'));
    await tester.tap(find.text('≤ 15 min'));
    await tester.pumpAndSettle();
    expect(find.text('Untagged'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('deleting the last task shows the hint, and Undo brings it back', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Pay rent', date: '2026-09-28');
    });
    await tester.drag(find.text('Pay rent'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Pay rent'), findsNothing);
    expect(find.text('Nothing planned. Add something small.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Pay rent'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping a task title opens it for editing', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Draft email', date: '2026-09-28');
    });
    await tester.tap(find.text('Draft email'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/tasks_card_test.dart`
Expected: FAIL, because `task_tile.dart` is not found.

- [ ] **Step 3: Implement `lib/ui/widgets/tide_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../tide_colors.dart';
import '../typography.dart';

/// White (or dark) rounded card from spec §3.4: 18 px radius, 16 px padding, no shadow.
class TideCard extends StatelessWidget {
  const TideCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Row(children: [
              Expanded(child: Text(title!, style: TideType.label(c.muted))),
              if (trailing != null) trailing!,
            ]),
          if (title != null) const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `lib/features/tasks/task_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'task_labels.dart';

class TaskTile extends StatefulWidget {
  const TaskTile({super.key, required this.task, required this.onToggle, required this.onOpen});

  final Task task;
  final Future<void> Function() onToggle;
  final VoidCallback onOpen;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  static const _fillPart = Interval(0, 0.47, curve: Motion.ease);
  static const _strikePart = Interval(0.47, 1, curve: Motion.ease);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.lightImpact();
    if (widget.task.isDone) {
      await widget.onToggle();
      return;
    }
    if (_c.isAnimating || _c.value == 1) return;
    _c.duration = motion(context, Motion.taskCheck + Motion.strike);
    await _c.forward(from: 0);
    await widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final task = widget.task;
    final meta = taskMeta(task);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final fill = task.isDone ? 1.0 : _fillPart.transform(_c.value);
        final strike = task.isDone ? 1.0 : _strikePart.transform(_c.value);
        final ink = Color.lerp(c.ink, c.muted, strike)!;
        return Row(
          children: [
            InkResponse(
              key: ValueKey('check-${task.id}'),
              onTap: _toggle,
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _CheckCircle(fill: fill, ring: c.warm, color: c.accent),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: widget.onOpen,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StrikeText(task.title, progress: strike, style: TideType.body(ink)),
                      if (meta.isNotEmpty) Text(meta, style: TideType.label(c.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.fill, required this.ring, required this.color});

  final double fill;
  final Color ring;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: fill > 0 ? color : ring, width: 2),
      ),
      alignment: Alignment.center,
      child: Transform.scale(
        scale: fill,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: fill == 1 ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        ),
      ),
    );
  }
}

/// Single-line text with a strike line drawn left-to-right as [progress] goes 0 → 1.
class StrikeText extends StatelessWidget {
  const StrikeText(this.text, {super.key, required this.progress, required this.style});

  final String text;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        ellipsis: '…',
        textDirection: Directionality.of(context),
      )..layout(maxWidth: constraints.maxWidth);
      final width = painter.width;
      painter.dispose();
      return CustomPaint(
        foregroundPainter: _StrikePainter(progress: progress, width: width, color: style.color!),
        child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    });
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter({required this.progress, required this.width, required this.color});

  final double progress;
  final double width;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(width * progress, y),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.width != width || old.color != color;
}
```

- [ ] **Step 5: Implement `lib/features/tasks/tasks_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import 'providers.dart';
import 'task_editor_sheet.dart';
import 'task_filter.dart';
import 'task_labels.dart';
import 'task_tile.dart';

class TasksCard extends ConsumerStatefulWidget {
  const TasksCard({super.key, this.trailing});

  /// Header action (the "Later" link, added in Task 5).
  final Widget? trailing;

  @override
  ConsumerState<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends ConsumerState<TasksCard> {
  /// Hidden the moment a row is swiped away, before the stream catches up.
  final _hidden = <String>{};

  Future<void> _delete(Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(task.id));
    await repo.delete(task.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Task deleted'),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.restore(task.id);
            if (mounted) setState(() => _hidden.remove(task.id));
          },
        ),
      ));
  }

  Widget _row(Task task) {
    final c = context.tide;
    final repo = ref.read(taskRepositoryProvider);
    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      direction: DismissDirection.endToStart,
      movementDuration: motion(context, const Duration(milliseconds: 200)),
      resizeDuration: motion(context, const Duration(milliseconds: 300)),
      onDismissed: (_) => _delete(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline, color: c.muted),
      ),
      child: TaskTile(
        task: task,
        onToggle: () => task.isDone ? repo.uncomplete(task.id) : repo.complete(task.id),
        onOpen: () => showTaskEditor(context, task: task),
      ),
    );
  }

  Widget _reorderable(List<Task> tasks) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final ids = [for (final t in tasks) t.id];
        ids.insert(newIndex, ids.removeAt(oldIndex));
        ref.read(taskRepositoryProvider).reorder(ids);
      },
      children: [
        for (var i = 0; i < tasks.length; i++)
          ReorderableDelayedDragStartListener(
            key: ValueKey(tasks[i].id),
            index: i,
            child: _row(tasks[i]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final filter = ref.watch(taskFilterProvider);
    final open = ref
        .watch(todayOpenTasksProvider)
        .listOrEmpty
        .where((t) => !_hidden.contains(t.id))
        .toList();
    final done = ref
        .watch(todayDoneTasksProvider)
        .listOrEmpty
        .where((t) => !_hidden.contains(t.id))
        .toList();
    final shown = filterTasks(open, filter);

    Widget hint(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text, style: TideType.body(c.muted)),
        );

    return TideCard(
      title: 'Tasks',
      trailing: widget.trailing,
      child: AnimatedSize(
        duration: motion(context, Motion.settle),
        curve: Motion.ease,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open.isNotEmpty) _FilterChips(filter: filter),
            if (open.isEmpty && done.isEmpty) hint('Nothing planned. Add something small.'),
            if (open.isNotEmpty && shown.isEmpty) hint('Nothing matches. Try another filter.'),
            if (shown.isNotEmpty)
              filter.isEmpty ? _reorderable(shown) : Column(children: [for (final t in shown) _row(t)]),
            for (final t in done) KeyedSubtree(key: ValueKey('done-${t.id}'), child: _row(t)),
            InkWell(
              onTap: () => showTaskEditor(context),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.add, size: 22, color: c.muted),
                  ),
                  Text('Add task', style: TideType.body(c.muted)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter});

  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final e in Energy.values)
            FilterChip(
              label: Text(energyLabel(e)),
              selected: filter.energy == e,
              onSelected: (_) => notifier.toggleEnergy(e),
            ),
          for (final m in const [15, 30])
            FilterChip(
              label: Text('≤ $m min'),
              selected: filter.maxMinutes == m,
              onSelected: (_) => notifier.toggleMaxMinutes(m),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Put the card on Today**

Replace `lib/features/today/today_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../tasks/tasks_card.dart';
import 'inbox_line.dart';
import 'today_header.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: const [
          TodayHeader(),
          SizedBox(height: 24),
          TasksCard(),
          SizedBox(height: 8),
          InboxLine(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

If the analyzer reports `onReorder` as deprecated, switch to the replacement it names (`onReorderItem`). That callback's `newIndex` is already adjusted, so delete the `if (newIndex > oldIndex) newIndex -= 1;` line.

- [ ] **Step 8: Commit and push**

```bash
git add lib test
git commit -m "feat: add tasks card to Today"
git push
```

---

### Task 5: Later screen

**Files:**
- Create: `lib/features/tasks/later_screen.dart`, `test/widget/later_test.dart`
- Modify: `lib/router.dart`, `lib/features/today/today_screen.dart`

**Interfaces:**
- Consumes: `laterTasksProvider`, `taskRepositoryProvider`, `todayKeyProvider`, `showTaskEditor`, `calmPage` and `TideCard`.
- Produces:
  - `LaterScreen`
  - The route `/today/later`
  - `LaterLink`: the header action "Later · N".

- [ ] **Step 1: Write the failing test**

`test/widget/later_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/task_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('undated tasks wait in Later and can be moved to today', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Sort photos');
    });
    expect(find.text('Sort photos'), findsNothing);
    expect(find.text('Later · 1'), findsOneWidget);

    await tester.tap(find.text('Later · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Sort photos'), findsOneWidget);

    await tester.tap(find.text('Do today'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing for later'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sort photos'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/later_test.dart`
Expected: FAIL, because `Later · 1` is not found.

- [ ] **Step 3: Implement `lib/features/tasks/later_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/async_x.dart';
import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'providers.dart';
import 'task_editor_sheet.dart';
import 'task_labels.dart';

/// "Later · 3" link for the Tasks card header.
class LaterLink extends ConsumerWidget {
  const LaterLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(laterTasksProvider).listOrEmpty.length;
    return TextButton(
      onPressed: () => context.go('/today/later'),
      child: Text(count == 0 ? 'Later' : 'Later · $count'),
    );
  }
}

class LaterScreen extends ConsumerWidget {
  const LaterScreen({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Task task) async {
    final now = ref.read(nowProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day + 1),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) await ref.read(taskRepositoryProvider).setDate(task.id, dateKey(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final tasks = ref.watch(laterTasksProvider).listOrEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('Later', style: TideType.title(c.ink))),
      body: tasks.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Nothing for later', style: TideType.title(c.ink)),
                const SizedBox(height: 4),
                Text('Tasks without a date wait here.', style: TideType.body(c.muted)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final task = tasks[i];
                final meta = taskMeta(task);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration:
                      BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => showTaskEditor(context, task: task),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(task.title, style: TideType.body(c.ink)),
                          if (meta.isNotEmpty) Text(meta, style: TideType.label(c.muted)),
                        ]),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pick a date',
                      icon: Icon(Icons.event_outlined, color: c.muted),
                      onPressed: () => _pickDate(context, ref, task),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(taskRepositoryProvider)
                          .setDate(task.id, ref.read(todayKeyProvider)),
                      child: const Text('Do today'),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 4: Wire up the route and the link**

In `lib/router.dart`, add `import 'features/tasks/later_screen.dart';`, then add a second child route inside the `/today` route's `routes: [...]`, after the `inbox` route:

```dart
                  GoRoute(
                    path: 'later',
                    pageBuilder: (context, state) => calmPage(state, const LaterScreen()),
                  ),
```

In `lib/features/today/today_screen.dart`, add `import '../tasks/later_screen.dart';` and change `TasksCard(),` to `TasksCard(trailing: LaterLink()),`.

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib test/widget/later_test.dart
git commit -m "feat: add Later list for undated tasks"
git push
```

---

### Task 6: Make task from the Inbox

**Files:**
- Modify: `lib/data/repositories/capture_repository.dart`, `lib/features/capture/inbox_screen.dart`, `test/unit/capture_repository_test.dart`
- Create: `test/widget/make_task_test.dart`

**Interfaces:**
- Consumes: `showTaskEditor(context, initialTitle:)`
- Produces: `CaptureRepository.markConverted(String id)`. Tapping an Inbox tile opens the task editor, prefilled with the capture's text. Saving marks the capture as converted.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` in `test/unit/capture_repository_test.dart`:

```dart
  test('markConverted removes a capture from the inbox', () async {
    final c = await repo.add('Book a table');
    await repo.markConverted(c!.id);
    expect(await inboxBodies(), isEmpty);
  });
```

`test/widget/make_task_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/capture_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('tapping a capture turns it into a task for today', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Book a table for Friday');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book a table for Friday'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to sort'), findsOneWidget);
    expect(find.text('Task added'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Book a table for Friday'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('closing the editor without saving leaves the capture in the inbox', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Maybe later');
    });
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // tap the barrier
    await tester.pumpAndSettle();
    expect(find.text('Maybe later'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/unit/capture_repository_test.dart test/widget/make_task_test.dart`
Expected: FAIL, because `markConverted` isn't defined.

- [ ] **Step 3: Implement**

In `lib/data/repositories/capture_repository.dart`, add after `unarchive`:

```dart
  Future<void> markConverted(String id) => _setStatus(id, CaptureStatus.converted);
```

In `lib/features/capture/inbox_screen.dart`, add `import '../tasks/task_editor_sheet.dart';` and this method to `_InboxScreenState`:

```dart
  Future<void> _makeTask(Capture capture) async {
    final repo = ref.read(captureRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showTaskEditor(context, initialTitle: capture.body);
    if (!saved) return;
    setState(() => _hidden.add(capture.id));
    await repo.markConverted(capture.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Task added'), duration: Duration(seconds: 2)));
  }
```

In `_list`, replace the Dismissible's `child: Container(...)` with:

```dart
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _makeTask(capture),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      capture.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TideType.body(c.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.add_task, size: 20, color: c.muted),
                ]),
              ),
            ),
          ),
```

- [ ] **Step 4: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` (this includes M1's inbox truncation test, which still finds the `Text` with `maxLines: 4`) and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib test
git commit -m "feat: turn inbox captures into tasks"
git push
```

---

### Task 7: Habit repository

**Files:**
- Create: `lib/data/repositories/habit_repository.dart`, `test/unit/habit_repository_test.dart`
- Modify: `lib/data/providers.dart`

**Interfaces:**
- Produces:
  - `class Habit`, with fields `id`, `name`, `icon`, `dailyTarget`, `goalId?` and `sortOrder`.
  - `class HabitToday`, with `habit` and `count`, plus the getters `done` (`count >= dailyTarget`) and `shown` (`count` clamped to the target).
  - `class HabitRepository`, constructed as `HabitRepository(AppDatabase, Clock, {Uuid? uuid})`, with these methods:
    - `Stream<List<HabitToday>> watchDay(String day)`
    - `Stream<List<Habit>> watchActive()`
    - `Future<Habit?> add({required String name, required String icon, int dailyTarget = 1, String? goalId})`
    - `Future<void> update(String id, {required String name, required String icon, required int dailyTarget, String? goalId})`
    - `Future<void> archive(String id)`
    - `Future<void> reorder(List<String> ids)`
    - `Future<int> tap(String habitId, String day)`: returns the new count. A tap on a habit that is already done resets it to 0.
    - `Future<Set<String>> completedDays(String habitId, {required String from, required String to})`
    - `Future<int> activeCount()`
  - `habitRepositoryProvider`
- `dailyTarget` is clamped to the range 1–20.

- [ ] **Step 1: Write the failing test**

`test/unit/habit_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/habit_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late HabitRepository repo;

  setUp(() {
    db = testDb();
    repo = HabitRepository(db, FakeClock(DateTime(2026, 9, 28, 9)));
  });
  tearDown(() => db.close());

  Future<Map<String, int>> counts(String day) async =>
      {for (final h in await repo.watchDay(day).first) h.habit.name: h.count};

  test('add trims, clamps the target and rejects blank names', () async {
    final h = await repo.add(name: '  Water ', icon: 'water', dailyTarget: 99);
    expect(h!.name, 'Water');
    expect(h.dailyTarget, 20);
    expect(await repo.add(name: ' ', icon: 'water'), isNull);
  });

  test('a new day starts at zero', () async {
    final h = await repo.add(name: 'Read', icon: 'book');
    await repo.tap(h!.id, '2026-09-28');
    expect(await counts('2026-09-28'), {'Read': 1});
    expect(await counts('2026-09-29'), {'Read': 0});
  });

  test('tap counts up to the target, then resets to zero', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 3);
    expect(await repo.tap(h!.id, '2026-09-28'), 1);
    expect(await repo.tap(h.id, '2026-09-28'), 2);
    expect(await repo.tap(h.id, '2026-09-28'), 3);
    final today = (await repo.watchDay('2026-09-28').first).single;
    expect(today.done, isTrue);
    expect(await repo.tap(h.id, '2026-09-28'), 0);
  });

  test('lowering the target keeps it done and never shows more than the target', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 8);
    for (var i = 0; i < 8; i++) {
      await repo.tap(h!.id, '2026-09-28');
    }
    await repo.update(h!.id, name: 'Water', icon: 'water', dailyTarget: 4);
    final today = (await repo.watchDay('2026-09-28').first).single;
    expect(today.done, isTrue);
    expect(today.shown, 4);
    expect(await repo.tap(h.id, '2026-09-28'), 0);
  });

  test('archived habits disappear from the day but keep their history', () async {
    final h = await repo.add(name: 'Stretch', icon: 'yoga');
    await repo.tap(h!.id, '2026-09-27');
    await repo.archive(h.id);
    expect(await counts('2026-09-28'), isEmpty);
    expect(await repo.completedDays(h.id, from: '2026-09-01', to: '2026-09-28'), {'2026-09-27'});
  });

  test('completedDays only counts days that met the target', () async {
    final h = await repo.add(name: 'Water', icon: 'water', dailyTarget: 2);
    await repo.tap(h!.id, '2026-09-26');
    await repo.tap(h.id, '2026-09-26');
    await repo.tap(h.id, '2026-09-27');
    expect(await repo.completedDays(h.id, from: '2026-09-20', to: '2026-09-28'), {'2026-09-26'});
  });

  test('reorder and activeCount', () async {
    final a = await repo.add(name: 'a', icon: 'book');
    final b = await repo.add(name: 'b', icon: 'book');
    await repo.reorder([b!.id, a!.id]);
    expect((await repo.watchActive().first).map((h) => h.name), ['b', 'a']);
    expect(await repo.activeCount(), 2);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/unit/habit_repository_test.dart`
Expected: FAIL, because `habit_repository.dart` is not found.

- [ ] **Step 3: Implement `lib/data/repositories/habit_repository.dart`**

```dart
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.dailyTarget,
    required this.sortOrder,
    this.goalId,
  });

  final String id;
  final String name;
  final String icon;
  final int dailyTarget;
  final String? goalId;
  final int sortOrder;
}

class HabitToday {
  const HabitToday({required this.habit, required this.count});

  final Habit habit;
  final int count;

  bool get done => count >= habit.dailyTarget;

  /// Count as shown to the user: never more than the target.
  int get shown => math.min(count, habit.dailyTarget);
}

class HabitRepository {
  HabitRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static const maxTarget = 20;

  DateTime _now() => _clock.now().toUtc();

  int _clampTarget(int t) => t.clamp(1, maxTarget);

  Stream<List<HabitToday>> watchDay(String day) {
    final h = _db.habits;
    final t = _db.habitTicks;
    final q = _db.select(h).join([
      leftOuterJoin(t, t.habitId.equalsExp(h.id) & t.date.equals(day)),
    ])
      ..where(h.archived.equals(false) & h.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(h.sortOrder), OrderingTerm.asc(h.createdAt)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            HabitToday(habit: _toHabit(r.readTable(h)), count: r.readTableOrNull(t)?.count ?? 0),
        ]);
  }

  Stream<List<Habit>> watchActive() {
    final q = _db.select(_db.habits)
      ..where((h) => h.archived.equals(false) & h.deletedAt.isNull())
      ..orderBy([(h) => OrderingTerm.asc(h.sortOrder), (h) => OrderingTerm.asc(h.createdAt)]);
    return q.watch().map((rows) => rows.map(_toHabit).toList());
  }

  Future<int> activeCount() async => (await watchActive().first).length;

  Future<Habit?> add({
    required String name,
    required String icon,
    int dailyTarget = 1,
    String? goalId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final now = _now();
    final id = _uuid.v4();
    final max = _db.habits.sortOrder.max();
    final next = ((await (_db.selectOnly(_db.habits)..addColumns([max])).getSingle()).read(max) ?? -1) + 1;
    await _db.into(_db.habits).insert(HabitsCompanion.insert(
          id: id,
          createdAt: now,
          updatedAt: now,
          name: clean,
          icon: icon,
          dailyTarget: Value(_clampTarget(dailyTarget)),
          goalId: Value(goalId),
          sortOrder: Value(next),
        ));
    return _toHabit(await (_db.select(_db.habits)..where((h) => h.id.equals(id))).getSingle());
  }

  Future<void> update(
    String id, {
    required String name,
    required String icon,
    required int dailyTarget,
    String? goalId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _write(
        id,
        HabitsCompanion(
          name: Value(clean),
          icon: Value(icon),
          dailyTarget: Value(_clampTarget(dailyTarget)),
          goalId: Value(goalId),
        ));
  }

  Future<void> archive(String id) => _write(id, const HabitsCompanion(archived: Value(true)));

  Future<void> reorder(List<String> ids) => _db.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await _write(ids[i], HabitsCompanion(sortOrder: Value(i)));
        }
      });

  /// One tap: +1 up to the target; a tap on a done habit resets today to 0.
  Future<int> tap(String habitId, String day) => _db.transaction(() async {
        final habit =
            await (_db.select(_db.habits)..where((h) => h.id.equals(habitId))).getSingle();
        final tick = await (_db.select(_db.habitTicks)
              ..where((t) => t.habitId.equals(habitId) & t.date.equals(day)))
            .getSingleOrNull();
        final now = _now();
        if (tick == null) {
          await _db.into(_db.habitTicks).insert(HabitTicksCompanion.insert(
                id: _uuid.v4(),
                createdAt: now,
                updatedAt: now,
                habitId: habitId,
                date: day,
                count: 1,
              ));
          return 1;
        }
        final next = tick.count >= habit.dailyTarget ? 0 : tick.count + 1;
        await (_db.update(_db.habitTicks)..where((t) => t.id.equals(tick.id)))
            .write(HabitTicksCompanion(count: Value(next), updatedAt: Value(now)));
        return next;
      });

  /// Dates in [from, to] (inclusive, `yyyy-MM-dd`) on which the habit met its current target.
  Future<Set<String>> completedDays(String habitId,
      {required String from, required String to}) async {
    final habit =
        await (_db.select(_db.habits)..where((h) => h.id.equals(habitId))).getSingle();
    final ticks = await (_db.select(_db.habitTicks)
          ..where((t) =>
              t.habitId.equals(habitId) &
              t.date.isBiggerOrEqualValue(from) &
              t.date.isSmallerOrEqualValue(to)))
        .get();
    return {for (final t in ticks) if (t.count >= habit.dailyTarget) t.date};
  }

  Future<void> _write(String id, HabitsCompanion changes) =>
      (_db.update(_db.habits)..where((h) => h.id.equals(id)))
          .write(changes.copyWith(updatedAt: Value(_now())));

  static Habit _toHabit(HabitRow r) => Habit(
        id: r.id,
        name: r.name,
        icon: r.icon,
        dailyTarget: r.dailyTarget,
        goalId: r.goalId,
        sortOrder: r.sortOrder,
      );
}
```

Append to `lib/data/providers.dart`, and add `import 'repositories/habit_repository.dart';`:

```dart
final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `flutter test test/unit/habit_repository_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 5: Commit and push**

```bash
git add lib/data test/unit/habit_repository_test.dart
git commit -m "feat: add habit repository with per-day ticks"
git push
```

---

### Task 8: Habit icons and editor

**Files:**
- Create: `lib/features/habits/habit_icons.dart`, `lib/features/habits/habit_editor_sheet.dart`, `test/widget/habit_editor_test.dart`

**Interfaces:**
- Consumes: `habitRepositoryProvider` and `Habit`.
- Produces:
  - Icons: `const habitIcons` (a `Map<String, IconData>` with 24 entries) and `IconData iconFor(String key)`.
  - `Future<bool> showHabitEditor(BuildContext, {Habit? habit})`
- **Ruling:** habits are added and edited from the Habits card in Milestone 2 (the + button, and long-press → "Edit habit"). Spec §4.7 puts habit management in Settings. Settings arrives in Milestone 5 and will open this same editor, so habits are usable now without waiting for Settings.

- [ ] **Step 1: Write the failing test**

`test/widget/habit_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/habits/habit_editor_sheet.dart';
import 'package:tide/features/habits/habit_icons.dart';

import '../support/fake_clock.dart';
import '../support/harness.dart';
import '../support/pump_app.dart';

void main() {
  test('there are 24 habit icons', () {
    expect(habitIcons, hasLength(24));
    expect(iconFor('nope'), Icons.circle_outlined);
  });

  testWidgets('creates a habit with an icon and a daily target', (tester) async {
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Water');
    await tester.tap(find.byTooltip('water'));
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byTooltip('More'));
    }
    await tester.pump();
    expect(find.text('8 times a day'), findsOneWidget);
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();

    final row = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(row.name, 'Water');
    expect(row.icon, 'water');
    expect(row.dailyTarget, 8);
    await disposeTideApp(tester, db);
  });

  testWidgets('blank name shows a gentle error', (tester) async {
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();
    expect(find.text('Give it a name first'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a ninth habit shows the keep-it-light note but still saves', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 9));
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c), child: const Text('Open')), clock: clock);
    await tester.runAsync(() async {
      final repo = HabitRepository(db, clock);
      for (var i = 0; i < 8; i++) {
        await repo.add(name: 'h$i', icon: 'book');
      }
    });
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Keeping it light'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ninth');
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => db.select(db.habits).get()), hasLength(9));
    await disposeTideApp(tester, db);
  });

  testWidgets('archiving asks first, then hides the habit', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 9));
    late Habit habit;
    final db = await pumpHarness(tester, (c) => TextButton(
        onPressed: () => showHabitEditor(c, habit: habit), child: const Text('Open')),
        clock: clock);
    habit = (await tester.runAsync(
        () => HabitRepository(db, clock).add(name: 'Stretch', icon: 'yoga')))!;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Stretch'), findsOneWidget);
    await tester.tap(find.text('Archive habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.habits).getSingle()))!;
    expect(row.archived, isTrue);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/habit_editor_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement `lib/features/habits/habit_icons.dart`**

```dart
import 'package:flutter/material.dart';

/// Curated outline icons for habits. Keys are stored in the database.
const habitIcons = <String, IconData>{
  'book': Icons.menu_book_outlined,
  'water': Icons.water_drop_outlined,
  'run': Icons.directions_run,
  'walk': Icons.directions_walk,
  'yoga': Icons.self_improvement,
  'calm': Icons.spa_outlined,
  'sleep': Icons.bedtime_outlined,
  'greens': Icons.eco_outlined,
  'pill': Icons.medication_outlined,
  'journal': Icons.edit_note,
  'music': Icons.music_note_outlined,
  'sun': Icons.wb_sunny_outlined,
  'bike': Icons.directions_bike,
  'swim': Icons.pool,
  'gym': Icons.fitness_center,
  'code': Icons.code,
  'language': Icons.translate,
  'plant': Icons.local_florist_outlined,
  'tidy': Icons.cleaning_services_outlined,
  'screen': Icons.do_not_disturb_on_outlined,
  'teeth': Icons.clean_hands_outlined,
  'kind': Icons.favorite_border,
  'no-drink': Icons.no_drinks_outlined,
  'call': Icons.call_outlined,
};

IconData iconFor(String key) => habitIcons[key] ?? Icons.circle_outlined;
```

- [ ] **Step 4: Implement `lib/features/habits/habit_editor_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_icons.dart';

const softHabitLimit = 8;

Future<bool> showHabitEditor(BuildContext context, {Habit? habit}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, Motion.sheet),
      reverseDuration: motion(context, Motion.quick),
    ),
    builder: (_) => HabitEditorSheet(habit: habit),
  );
  return saved ?? false;
}

class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.habit?.name ?? '');
  late String _icon = widget.habit?.icon ?? habitIcons.keys.first;
  late int _target = widget.habit?.dailyTarget ?? 1;
  String? _error;
  bool _saving = false;
  int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.habit == null) {
      ref.read(habitRepositoryProvider).activeCount().then((n) {
        if (mounted) setState(() => _activeCount = n);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name first');
      return;
    }
    _saving = true;
    final repo = ref.read(habitRepositoryProvider);
    try {
      final h = widget.habit;
      if (h == null) {
        await repo.add(name: _name.text, icon: _icon, dailyTarget: _target);
      } else {
        await repo.update(h.id,
            name: _name.text, icon: _icon, dailyTarget: _target, goalId: h.goalId);
      }
      _close();
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  Future<void> _archive() async {
    final h = widget.habit!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${h.name}?'),
        content: const Text("It'll disappear from Today. Your history is kept."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(habitRepositoryProvider).archive(h.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final editing = widget.habit != null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing ? 'Edit habit' : 'New habit', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Read', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (!editing && _activeCount >= softHabitLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You already have $_activeCount habits. Keeping it light helps them stick.',
                style: TideType.label(c.muted),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in habitIcons.entries)
                Tooltip(
                  message: entry.key,
                  child: InkResponse(
                    onTap: () => setState(() => _icon = entry.key),
                    radius: 24,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _icon == entry.key ? c.accent : c.background,
                      ),
                      child: Icon(entry.value,
                          size: 20, color: _icon == entry.key ? Colors.white : c.ink),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: 'Fewer',
                onPressed: _target > 1 ? () => setState(() => _target--) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  _target == 1 ? 'Once a day' : '$_target times a day',
                  textAlign: TextAlign.center,
                  style: TideType.body(c.ink),
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: _target < HabitRepository.maxTarget
                    ? () => setState(() => _target++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(editing ? 'Save' : 'Save habit')),
          if (editing)
            TextButton(onPressed: _archive, child: const Text('Archive habit')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `flutter test test/widget/habit_editor_test.dart && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 6: Commit and push**

```bash
git add lib/features/habits test/widget/habit_editor_test.dart
git commit -m "feat: add habit icons and editor"
git push
```

---

### Task 9: Habit circle and Habits card

**Files:**
- Create: `lib/features/habits/providers.dart`, `lib/features/habits/habit_circle.dart`, `lib/features/habits/habits_card.dart`, `test/widget/habits_card_test.dart`
- Modify: `lib/features/today/today_screen.dart`

**Interfaces:**
- Consumes: `HabitRepository`, `todayKeyProvider`, `iconFor`, `showHabitEditor` and `TideCard`.
- Produces:
  - `todayHabitsProvider`: a `StreamProvider<List<HabitToday>>`.
  - `HabitCircle({required HabitToday item, required VoidCallback onTap, VoidCallback? onLongPress})`, keyed `ValueKey('habit-<id>')`.
  - `HabitsCard({void Function(Habit)? onLongPress})`. Task 10 passes the history opener through `onLongPress`.

- [ ] **Step 1: Write the failing test**

`test/widget/habits_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/features/habits/habit_circle.dart';
import 'package:tide/features/habits/habits_card.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

void main() {
  HabitCircle circle(WidgetTester tester, Habit h) =>
      tester.widget<HabitCircle>(find.byKey(ValueKey('habit-${h.id}')));

  testWidgets('empty card invites a first habit', (tester) async {
    final db = await pumpTideApp(tester);
    expect(find.text("Add a habit or two you'd like to keep."), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('tapping a once-a-day habit completes it, tapping again undoes it', (tester) async {
    late Habit read;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      read = (await HabitRepository(db, clock).add(name: 'Read', icon: 'book'))!;
    });
    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isTrue);

    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isFalse);
    await disposeTideApp(tester, db);
  });

  testWidgets('counted habits show a gentle caption', (tester) async {
    late Habit water;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      water = (await HabitRepository(db, clock).add(name: 'Water', icon: 'water', dailyTarget: 8))!;
    });
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('habit-${water.id}')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Water 3 of 8'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Water 3 of 8'), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('a new day starts fresh while the app stays open', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 21));
    late Habit read;
    final db = await pumpTideApp(tester, clock: clock, seed: (db, clock) async {
      read = (await HabitRepository(db, clock).add(name: 'Read', icon: 'book'))!;
    });
    await tester.tap(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();
    expect(circle(tester, read).item.done, isTrue);

    clock.set(DateTime(2026, 9, 29, 7));
    ProviderScope.containerOf(tester.element(find.byType(HabitsCard)))
        .read(nowProvider.notifier)
        .refresh();
    await tester.pumpAndSettle();

    expect(circle(tester, read).item.done, isFalse);
    expect(find.text('Tuesday, 29 Sep'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/widget/habits_card_test.dart`
Expected: FAIL, because the imports are not found.

- [ ] **Step 3: Implement `lib/features/habits/providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';

final todayHabitsProvider = StreamProvider<List<HabitToday>>((ref) =>
    ref.watch(habitRepositoryProvider).watchDay(ref.watch(todayKeyProvider)));
```

- [ ] **Step 4: Implement `lib/features/habits/habit_circle.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_icons.dart';

class HabitCircle extends StatefulWidget {
  const HabitCircle({super.key, required this.item, required this.onTap, this.onLongPress});

  final HabitToday item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<HabitCircle> createState() => _HabitCircleState();
}

class _HabitCircleState extends State<HabitCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this);

  @override
  void didUpdateWidget(HabitCircle old) {
    super.didUpdateWidget(old);
    if (!old.item.done && widget.item.done) {
      _ripple.duration = motion(context, Motion.ripple);
      _ripple.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final item = widget.item;
    final target = item.habit.dailyTarget;
    final progress = item.shown / target;
    const size = 52.0;
    return Semantics(
      button: true,
      label: target == 1
          ? '${item.habit.name}, ${item.done ? 'done' : 'not done'}'
          : '${item.habit.name}, ${item.shown} of $target',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _ripple,
                      builder: (context, _) => _ripple.isAnimating
                          ? Transform.scale(
                              scale: 1 + 0.8 * Motion.ease.transform(_ripple.value),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.accent.withValues(alpha: 0.6 * (1 - _ripple.value)),
                                    width: 2,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: motion(context, Motion.ringFill),
                      curve: Motion.ease,
                      builder: (context, value, _) => CustomPaint(
                        size: const Size.square(size),
                        painter: _RingPainter(
                          progress: value,
                          segments: target,
                          track: c.soft,
                          color: c.accent,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: item.done ? 1 : 0,
                      duration: motion(context, Motion.bloom),
                      curve: Motion.ease,
                      child: Container(
                        width: size - 6,
                        height: size - 6,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                    ),
                    Icon(iconFor(item.habit.icon),
                        size: 22, color: item.done ? Colors.white : c.accent),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TideType.label(c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Track plus progress arc; split into [segments] with small gaps when segments > 1.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.segments,
    required this.track,
    required this.color,
  });

  final double progress;
  final int segments;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final gap = segments > 1 ? 0.12 : 0.0;
    final sweepEach = (2 * math.pi) / segments;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final filled = progress * segments;
    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * sweepEach + gap / 2;
      final sweep = sweepEach - gap;
      canvas.drawArc(arcRect, start, sweep, false, trackPaint);
      final part = (filled - i).clamp(0.0, 1.0);
      if (part > 0) canvas.drawArc(arcRect, start, sweep * part, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.color != color ||
      old.track != track;
}
```

- [ ] **Step 5: Implement `lib/features/habits/habits_card.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/async_x.dart';
import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import 'habit_circle.dart';
import 'habit_editor_sheet.dart';
import 'providers.dart';

class HabitsCard extends ConsumerStatefulWidget {
  const HabitsCard({super.key, this.onLongPress});

  final void Function(Habit habit)? onLongPress;

  @override
  ConsumerState<HabitsCard> createState() => _HabitsCardState();
}

class _HabitsCardState extends ConsumerState<HabitsCard> {
  String? _caption;
  Timer? _captionTimer;

  @override
  void dispose() {
    _captionTimer?.cancel();
    super.dispose();
  }

  Future<void> _tap(HabitToday item) async {
    HapticFeedback.lightImpact();
    final next = await ref
        .read(habitRepositoryProvider)
        .tap(item.habit.id, ref.read(todayKeyProvider));
    final target = item.habit.dailyTarget;
    if (next >= target) HapticFeedback.mediumImpact();
    if (target > 1 && mounted) {
      _captionTimer?.cancel();
      setState(() => _caption = '${item.habit.name} ${next.clamp(0, target)} of $target');
      _captionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _caption = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final habits = ref.watch(todayHabitsProvider).listOrEmpty;
    return TideCard(
      title: 'Habits',
      trailing: IconButton(
        tooltip: 'Add habit',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.add, color: c.muted),
        onPressed: () => showHabitEditor(context),
      ),
      child: habits.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text("Add a habit or two you'd like to keep.",
                  style: TideType.body(c.muted)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final item in habits)
                      HabitCircle(
                        key: ValueKey('habit-${item.habit.id}'),
                        item: item,
                        onTap: () => _tap(item),
                        onLongPress: widget.onLongPress == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                widget.onLongPress!(item.habit);
                              },
                      ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: motion(context, Motion.quick),
                  child: _caption == null
                      ? const SizedBox(height: 8)
                      : Padding(
                          key: ValueKey(_caption),
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_caption!, style: TideType.label(c.muted)),
                        ),
                ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 6: Put the card on Today**

In `lib/features/today/today_screen.dart`, add `import '../habits/habits_card.dart';`, and insert these before `TasksCard(trailing: LaterLink()),`:

```dart
          HabitsCard(),
          SizedBox(height: 12),
```

- [ ] **Step 7: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 8: Commit and push**

```bash
git add lib test/widget/habits_card_test.dart
git commit -m "feat: add habits card with ring, bloom and ripple"
git push
```

---

### Task 10: Habit history sheet

**Files:**
- Create: `lib/features/habits/habit_history_sheet.dart`, `test/unit/weeks_grid_test.dart`, `test/widget/habit_history_test.dart`
- Modify: `lib/features/habits/providers.dart`, `lib/features/today/today_screen.dart`

**Interfaces:**
- Consumes: `HabitRepository.completedDays`, `todayKeyProvider` and `showHabitEditor`.
- Produces:
  - `List<List<String?>> weeksGrid(String today, {int weeks = 5})`: Monday-start weeks, with `null` for days after today.
  - `habitHistoryProvider`: a `FutureProvider.autoDispose.family<Set<String>, String>`.
  - `Future<void> showHabitHistory(BuildContext, Habit)`

- [ ] **Step 1: Write the failing tests**

`test/unit/weeks_grid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/habits/habit_history_sheet.dart';

void main() {
  test('five Monday-start weeks ending with the week containing today', () {
    final grid = weeksGrid('2026-09-28'); // a Monday
    expect(grid, hasLength(5));
    expect(grid.every((w) => w.length == 7), isTrue);
    expect(grid.last.first, '2026-09-28');
    expect(grid.last.skip(1).every((d) => d == null), isTrue);
    expect(grid.first.first, '2026-08-31');
  });

  test('mid-week today fills up to today only', () {
    final grid = weeksGrid('2026-10-01'); // Thursday
    expect(grid.last, ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', null, null, null]);
  });

  test('crosses a month boundary correctly', () {
    final grid = weeksGrid('2026-03-02', weeks: 2);
    expect(grid.first.first, '2026-02-23');
    expect(grid.first.last, '2026-03-01');
  });
}
```

`test/widget/habit_history_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/repositories/habit_repository.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('long-press shows a calm dot history with no numbers', (tester) async {
    late Habit read;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = HabitRepository(db, clock);
      read = (await repo.add(name: 'Read', icon: 'book'))!;
      await repo.tap(read.id, '2026-09-27');
      await repo.tap(read.id, '2026-09-28');
    });
    await tester.longPress(find.byKey(ValueKey('habit-${read.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Last 5 weeks'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-09-28-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-09-27-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-2026-09-26-open')), findsOneWidget);
    expect(find.textContaining('streak'), findsNothing);

    await tester.tap(find.text('Edit habit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit habit'), findsOneWidget); // the editor's header
    await disposeTideApp(tester, db);
  });
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/unit/weeks_grid_test.dart test/widget/habit_history_test.dart`
Expected: FAIL, because `habit_history_sheet.dart` is not found.

- [ ] **Step 3: Add the history provider**

Append to `lib/features/habits/providers.dart`:

```dart
final habitHistoryProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, habitId) async {
  final today = ref.watch(todayKeyProvider);
  final from = DateTime.parse(today).subtract(const Duration(days: 34));
  return ref.watch(habitRepositoryProvider).completedDays(
        habitId,
        from: dateKey(from),
        to: today,
      );
});
```

Also add `import '../../data/clock.dart';` to that file.

- [ ] **Step 4: Implement `lib/features/habits/habit_history_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_editor_sheet.dart';
import 'habit_icons.dart';
import 'providers.dart';

/// [weeks] rows of Monday-start weeks; the last row holds [today]. Future days are null.
List<List<String?>> weeksGrid(String today, {int weeks = 5}) {
  final t = DateTime.parse(today);
  final monday = DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));
  final first = DateTime(monday.year, monday.month, monday.day - 7 * (weeks - 1));
  return [
    for (var w = 0; w < weeks; w++)
      [
        for (var d = 0; d < 7; d++)
          () {
            final day = DateTime(first.year, first.month, first.day + w * 7 + d);
            return day.isAfter(t) ? null : dateKey(day);
          }(),
      ],
  ];
}

Future<void> showHabitHistory(BuildContext context, Habit habit) => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: AnimationStyle(
        duration: motion(context, Motion.sheet),
        reverseDuration: motion(context, Motion.quick),
      ),
      builder: (_) => _HabitHistorySheet(habit: habit),
    );

class _HabitHistorySheet extends ConsumerWidget {
  const _HabitHistorySheet({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final done = switch (ref.watch(habitHistoryProvider(habit.id))) {
      AsyncData(:final value) => value,
      _ => const <String>{},
    };
    final grid = weeksGrid(today);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(iconFor(habit.icon), color: c.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(habit.name, style: TideType.title(c.ink))),
          ]),
          const SizedBox(height: 4),
          Text('Last 5 weeks', style: TideType.label(c.muted)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in letters)
                SizedBox(
                  width: 28,
                  child: Text(l, textAlign: TextAlign.center, style: TideType.label(c.muted)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final week in grid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final day in week)
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: day == null
                            ? const SizedBox(width: 14, height: 14)
                            : Container(
                                key: ValueKey('dot-$day-${done.contains(day) ? 'done' : 'open'}'),
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done.contains(day) ? c.accent : c.soft,
                                  border: day == today
                                      ? Border.all(color: c.ink.withValues(alpha: 0.4))
                                      : null,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showHabitEditor(context, habit: habit);
            },
            child: const Text('Edit habit'),
          ),
        ],
      ),
    );
  }
}
```

The "Edit habit" button pops this sheet and then opens the editor from the same `context`. That context belongs to the sheet's route, which is still mounted during its exit animation, and `showModalBottomSheet` only uses it to find the Navigator. So this is safe.

- [ ] **Step 5: Wire up the long-press on Today**

In `lib/features/today/today_screen.dart`, add `import '../habits/habit_history_sheet.dart';`.

Because `showHabitHistory` needs a `BuildContext`, the list can no longer be `const`. Replace `HabitsCard(),` with:

```dart
          HabitsCard(onLongPress: (habit) => showHabitHistory(context, habit)),
```

Then remove `const` from `children: const [` and add `const` to each of the other children in that list.

- [ ] **Step 6: Run all tests and the analyzer**

Run: `flutter test && flutter analyze`
Expected: `All tests passed!` and `No issues found!`

- [ ] **Step 7: Commit and push**

```bash
git add lib test
git commit -m "feat: add 5-week habit history sheet"
git push
```

---

### Task 11: Device check

**Files:** none.

- [ ] **Step 1: Build and install**

```bash
flutter build apk --release
flutter install -d RFCX20G1V5B --release
```

Expected: `Installing ... app-release.apk`. Existing captures survive the upgrade, because the schema is still v1.

- [ ] **Step 2: USER STEP — feel check with Jason**

- [ ] Add a few tasks with and without tags. Complete one: the circle fills, the line strikes through, and the row settles below.
- [ ] Long-press and drag to reorder the open tasks.
- [ ] Filters: Low, then ≤ 15 min. Check the "Nothing matches" line.
- [ ] Swipe a task away, then Undo.
- [ ] Add a task with Later, then open "Later · 1" and tap "Do today".
- [ ] Inbox: tap a capture, then save it as a task.
- [ ] Add "Water" at 8 a day and tap it through the day. Check the ring segments, the bloom and ripple at 8, and the haptics.
- [ ] Long-press a habit to see its history, then tap Edit habit.

- [ ] **Step 3: Record notes, then commit and push**

Put any tuning notes into `docs/superpowers/plans/2026-09-29-m2-today-core-notes.md` if there are some, then:

```bash
git add -A
git commit -m "docs: record Milestone 2 device check"
git push
```
