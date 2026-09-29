import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/providers.dart';
import 'package:tide/data/repositories/capture_repository.dart';
import 'package:tide/features/capture/inbox_screen.dart';
import 'package:tide/features/capture/providers.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/widgets/calm_entry.dart';

import '../support/pump_app.dart';

/// Holds every save until [gate] completes.
class _GatedCaptures extends CaptureRepository {
  _GatedCaptures(super.db, super.clock, this.gate);
  final Completer<void> gate;

  @override
  Future<Capture?> add(String raw) async {
    await gate.future;
    return super.add(raw);
  }
}

class _BrokenArchive extends CaptureRepository {
  _BrokenArchive(super.db, super.clock);

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

  testWidgets('an inbox that fails to load says so instead of going blank', (tester) async {
    final db = await pumpTideApp(tester, seed: (db, clock) async {
      await CaptureRepository(db, clock).add('Something');
    }, overrides: [
      inboxProvider.overrideWith((ref) => Stream<List<Capture>>.error(Exception('disk'))),
    ]);
    await tester.tap(find.text('1 thought in your inbox'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your inbox."), findsOneWidget);
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
