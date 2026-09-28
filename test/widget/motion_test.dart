import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/ui/motion.dart';

void main() {
  Future<Duration> resolve(WidgetTester tester, {required bool reduce}) async {
    late Duration result;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Builder(builder: (context) {
        result = motion(context, Motion.sheet);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('keeps durations normally', (tester) async {
    expect(await resolve(tester, reduce: false), Motion.sheet);
  });

  testWidgets('drops durations to zero when animations are disabled', (tester) async {
    expect(await resolve(tester, reduce: true), Duration.zero);
  });
}
