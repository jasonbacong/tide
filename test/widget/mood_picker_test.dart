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
