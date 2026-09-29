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
