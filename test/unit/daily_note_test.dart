import 'package:flutter_test/flutter_test.dart';
import 'package:tide/content/daily_lines.dart';
import 'package:tide/features/today/daily_note.dart';

void main() {
  const today = '2026-09-28';

  test('60 original lines, all short and distinct', () {
    expect(dailyLines, hasLength(60));
    expect(dailyLines.toSet(), hasLength(60));
    expect(dailyLines.every((l) => l.length <= 80), isTrue);
  });

  test('resurfaces a reflection from exactly a month ago', () {
    final note = pickDailyNote(today: today, reflections: {'2026-08-29': 'Slow mornings suit me.'});
    expect(note.kind, NoteKind.resurfaced);
    expect(note.text, 'A month ago you wrote: “Slow mornings suit me.”');
  });

  test('allows ±2 days and prefers the exact day', () {
    expect(pickDailyNote(today: today, reflections: {'2026-08-31': 'two days off'}).text,
        contains('two days off'));
    expect(pickDailyNote(today: today, reflections: {'2026-09-01': 'three days off'}).kind,
        NoteKind.line);
    expect(
        pickDailyNote(today: today, reflections: {'2026-08-28': 'near', '2026-08-29': 'exact'}).text,
        contains('exact'));
  });

  test('checks a month, then three months, then a year', () {
    final all = {'2026-08-29': 'month', '2026-06-30': 'quarter', '2025-09-28': 'year'};
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('A month ago'));
    all.remove('2026-08-29');
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('Three months ago'));
    all.remove('2026-06-30');
    expect(pickDailyNote(today: today, reflections: all).text, startsWith('A year ago'));
  });

  test('falls back to a bundled line that is stable within a day and varies across days', () {
    final a = pickDailyNote(today: today, reflections: {});
    final b = pickDailyNote(today: today, reflections: {});
    final next = pickDailyNote(today: '2026-09-29', reflections: {});
    expect(a.kind, NoteKind.line);
    expect(a.text, b.text);
    expect(next.text, isNot(a.text));
    expect(dailyLines, contains(a.text));
  });

  test('truncateWords collapses whitespace and cuts at a word boundary', () {
    expect(truncateWords('short', 100), 'short');
    expect(truncateWords('line one\n\n  line two', 100), 'line one line two');
    final long = List.filled(40, 'word').join(' ');
    final cut = truncateWords(long, 100);
    expect(cut.length, lessThanOrEqualTo(101));
    expect(cut, endsWith('word…'));
  });
}
