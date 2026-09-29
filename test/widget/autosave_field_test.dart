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
