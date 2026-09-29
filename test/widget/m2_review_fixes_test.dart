import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/enums.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/habit_repository.dart';
import 'package:tide/data/repositories/task_repository.dart';
import 'package:tide/features/habits/providers.dart';
import 'package:tide/features/tasks/providers.dart';
import 'package:tide/features/tasks/task_tile.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';

import '../support/fake_clock.dart';
import '../support/pump_app.dart';

/// Holds reorders until [gate] completes, like a slow background isolate.
class _SlowReorder extends TaskRepository {
  _SlowReorder(super.db, super.clock, this.gate);
  final Completer<void> gate;

  @override
  Future<void> reorder(List<String> ids) async {
    await gate.future;
    return super.reorder(ids);
  }
}

void main() {
  testWidgets('while tasks and habits are still loading, no empty-state copy flashes',
      (tester) async {
    final db = await pumpTideApp(tester, overrides: [
      todayOpenTasksProvider.overrideWith((ref) => StreamController<List<Task>>().stream),
      todayHabitsProvider.overrideWith((ref) => StreamController<List<HabitToday>>().stream),
    ]);
    expect(find.text('Nothing planned. Add something small.'), findsNothing);
    expect(find.text("Add a habit or two you'd like to keep."), findsNothing);
    await disposeTideApp(tester, db);
  });

  testWidgets('a task list that fails to load says so instead of looking empty', (tester) async {
    final db = await pumpTideApp(tester, overrides: [
      todayOpenTasksProvider.overrideWith((ref) => Stream<List<Task>>.error(Exception('disk'))),
    ]);
    expect(find.text('Nothing planned. Add something small.'), findsNothing);
    expect(find.text("Couldn't load your tasks."), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a reorder shows the new order straight away', (tester) async {
    final gate = Completer<void>();
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      final repo = TaskRepository(db, clock);
      for (final t in ['A', 'B', 'C']) {
        await repo.add(title: t, date: '2026-09-28');
      }
    }, overrides: [
      taskRepositoryProvider.overrideWith(
          (ref) => _SlowReorder(ref.watch(databaseProvider), ref.watch(clockProvider), gate)),
    ]);
    final list = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    list.onReorderItem!(0, 2); // move A to the end
    await tester.pump();
    expect(tester.getTopLeft(find.text('A')).dy, greaterThan(tester.getTopLeft(find.text('C')).dy));
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('A')).dy, greaterThan(tester.getTopLeft(find.text('C')).dy));
    await disposeTideApp(tester, db);
  });

  testWidgets('the strike line matches the title width at a larger font size', (tester) async {
    const title = 'Call the dentist';
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light, PartOfDay.morning),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: const Scaffold(
            body: SizedBox(width: 380, child: StrikeText(title, progress: 1, style: TextStyle(fontSize: 15, color: Colors.black))),
          ),
        ),
      ),
    ));
    final paint = tester.widget<CustomPaint>(
        find.descendant(of: find.byType(StrikeText), matching: find.byType(CustomPaint)));
    final painter = paint.foregroundPainter! as StrikePainter;
    // The test font's glyphs are one em wide, so the true text width is length × size × scale.
    expect(painter.width, closeTo(title.length * 15 * 1.3, 1));
  });

  testWidgets('a task added while a filter is on is not hidden by it', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await TaskRepository(db, clock).add(title: 'Easy call', energy: Energy.low, date: '2026-09-28');
    });
    await tester.tap(find.text('Low'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Call the dentist'), 'Call mum');
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(find.text('Call mum'), findsOneWidget);
    await disposeTideApp(tester, db);
  });

  testWidgets('a tick is kept even if the row changes mid-animation', (tester) async {
    late Task t;
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      t = (await TaskRepository(db, clock).add(title: 'Stretch', energy: Energy.low, date: '2026-09-28'))!;
    });
    await tester.tap(find.byKey(ValueKey('check-${t.id}')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Low')); // swaps the list, disposing the animating tile
    await tester.pumpAndSettle();
    final row = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(row.completedAt, isNotNull);
    await disposeTideApp(tester, db);
  });

  testWidgets('the day rolls over right at midnight, not up to a minute later', (tester) async {
    final clock = FakeClock(DateTime(2026, 9, 28, 23, 59, 30));
    final db = await pumpTideApp(tester, clock: clock);
    clock.set(DateTime(2026, 9, 29, 0, 0, 1));
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday, 29 Sep'), findsOneWidget);
    await disposeTideApp(tester, db);
  });
}
