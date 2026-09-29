import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/daily_lines.dart';
import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

enum NoteKind { resurfaced, line }

class DailyNote {
  const DailyNote({required this.text, required this.kind});

  final String text;
  final NoteKind kind;
}

/// Collapses whitespace and cuts at the last word boundary within [max] chars, adding "…".
String truncateWords(String text, int max) {
  final flat = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (flat.length <= max) return flat;
  final cut = flat.substring(0, max);
  final space = cut.lastIndexOf(' ');
  return '${(space > 0 ? cut.substring(0, space) : cut).trimRight()}…';
}

const _windows = [
  (30, 'A month ago you wrote'),
  (90, 'Three months ago you wrote'),
  (365, 'A year ago you wrote'),
];
const _tolerance = [0, -1, 1, -2, 2];

/// Spec §4.6: resurface a past reflection (30 → 90 → 365 days, ±2), else a bundled line
/// seeded by the date.
DailyNote pickDailyNote({
  required String today,
  required Map<String, String> reflections,
  List<String> lines = dailyLines,
}) {
  final t = DateTime.parse(today);
  for (final (days, label) in _windows) {
    for (final offset in _tolerance) {
      final key = dateKey(DateTime(t.year, t.month, t.day - days + offset));
      final text = reflections[key]?.trim();
      if (text != null && text.isNotEmpty) {
        return DailyNote(
          text: '$label: “${truncateWords(text, 100)}”',
          kind: NoteKind.resurfaced,
        );
      }
    }
  }
  final seed = int.parse(today.replaceAll('-', ''));
  return DailyNote(text: lines[seed % lines.length], kind: NoteKind.line);
}

final dailyNoteProvider = FutureProvider<DailyNote>((ref) async {
  final today = ref.watch(todayKeyProvider);
  final t = DateTime.parse(today);
  final reflections = await ref.watch(checkInRepositoryProvider).reflectionsBetween(
        dateKey(DateTime(t.year, t.month, t.day - 367)),
        dateKey(DateTime(t.year, t.month, t.day - 28)),
      );
  return pickDailyNote(today: today, reflections: reflections);
});

class DailyNoteView extends ConsumerWidget {
  const DailyNoteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final note = ref.watch(dailyNoteProvider);
    return AnimatedSwitcher(
      duration: motion(context, Motion.quick),
      child: switch (note) {
        AsyncData(:final value) => Padding(
            key: ValueKey(value.text),
            padding: const EdgeInsets.only(top: 8),
            child: Text(value.text, style: TideType.note(c.muted)),
          ),
        _ => const SizedBox(height: 8),
      },
    );
  }
}
