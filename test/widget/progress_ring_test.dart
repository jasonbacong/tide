import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/day_period.dart';
import 'package:tide/ui/theme.dart';
import 'package:tide/ui/widgets/progress_ring.dart';

void main() {
  testWidgets('animates towards progress and clamps to 0..1', (tester) async {
    Future<void> show(double p) => tester.pumpWidget(MaterialApp(
          theme: buildTheme(Brightness.light, PartOfDay.morning),
          home: Center(child: ProgressRing(progress: p, size: 60)),
        ));
    await show(0.5);
    await tester.pumpAndSettle();
    await show(3);
    await tester.pumpAndSettle();
    final builder = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>));
    expect(builder.tween.end, 1.0);
  });
}
