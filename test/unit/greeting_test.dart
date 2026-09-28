import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/today/greeting.dart';
import 'package:tide/ui/day_period.dart';

void main() {
  test('greets by period with a name', () {
    expect(greetingFor(PartOfDay.morning, 'Jason'), 'Good morning, Jason');
    expect(greetingFor(PartOfDay.afternoon, 'Jason'), 'Good afternoon, Jason');
    expect(greetingFor(PartOfDay.evening, 'Jason'), 'Good evening, Jason');
    expect(greetingFor(PartOfDay.night, 'Jason'), 'Good evening, Jason');
  });

  test('drops the comma when no name is set', () {
    expect(greetingFor(PartOfDay.morning, ''), 'Good morning');
    expect(greetingFor(PartOfDay.morning, '   '), 'Good morning');
  });
}
