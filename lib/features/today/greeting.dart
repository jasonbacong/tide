import '../../ui/day_period.dart';

String greetingFor(PartOfDay period, String name) {
  final hello = switch (period) {
    PartOfDay.morning => 'Good morning',
    PartOfDay.afternoon => 'Good afternoon',
    PartOfDay.evening || PartOfDay.night => 'Good evening',
  };
  final trimmed = name.trim();
  return trimmed.isEmpty ? hello : '$hello, $trimmed';
}
