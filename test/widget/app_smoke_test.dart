import 'package:flutter_test/flutter_test.dart';
import 'package:tide/main.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const PlaceholderApp());
    expect(find.text('Tide'), findsOneWidget);
  });
}
