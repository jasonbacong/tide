import 'package:flutter_test/flutter_test.dart';
import 'package:tide/features/habits/habit_history_sheet.dart';

void main() {
  test('five Monday-start weeks ending with the week containing today', () {
    final grid = weeksGrid('2026-09-28'); // a Monday
    expect(grid, hasLength(5));
    expect(grid.every((w) => w.length == 7), isTrue);
    expect(grid.last.first, '2026-09-28');
    expect(grid.last.skip(1).every((d) => d == null), isTrue);
    expect(grid.first.first, '2026-08-31');
  });

  test('mid-week today fills up to today only', () {
    final grid = weeksGrid('2026-10-01'); // Thursday
    expect(grid.last, ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', null, null, null]);
  });

  test('crosses a month boundary correctly', () {
    final grid = weeksGrid('2026-03-02', weeks: 2);
    expect(grid.first.first, '2026-02-23');
    expect(grid.first.last, '2026-03-01');
  });
}
