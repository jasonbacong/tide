import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_editor_sheet.dart';
import 'habit_icons.dart';
import 'providers.dart';

/// [weeks] rows of Monday-start weeks; the last row holds [today]. Future days are null.
List<List<String?>> weeksGrid(String today, {int weeks = 5}) {
  final t = DateTime.parse(today);
  final monday = DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));
  final first = DateTime(monday.year, monday.month, monday.day - 7 * (weeks - 1));
  return [
    for (var w = 0; w < weeks; w++)
      [
        for (var d = 0; d < 7; d++)
          () {
            final day = DateTime(first.year, first.month, first.day + w * 7 + d);
            return day.isAfter(t) ? null : dateKey(day);
          }(),
      ],
  ];
}

Future<void> showHabitHistory(BuildContext context, Habit habit) => showModalBottomSheet<void>(
      context: context,
      // Above the tab shell's + button and bottom bar.
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: AnimationStyle(
        duration: motion(context, Motion.sheet),
        reverseDuration: motion(context, Motion.quick),
      ),
      builder: (_) => _HabitHistorySheet(habit: habit),
    );

class _HabitHistorySheet extends ConsumerWidget {
  const _HabitHistorySheet({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final done = switch (ref.watch(habitHistoryProvider(habit.id))) {
      AsyncData(:final value) => value,
      _ => const <String>{},
    };
    final grid = weeksGrid(today);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(iconFor(habit.icon), color: c.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(habit.name, style: TideType.title(c.ink))),
          ]),
          const SizedBox(height: 4),
          Text('Last 5 weeks', style: TideType.label(c.muted)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in letters)
                SizedBox(
                  width: 28,
                  child: Text(l, textAlign: TextAlign.center, style: TideType.label(c.muted)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final week in grid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final day in week)
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: day == null
                            ? const SizedBox(width: 14, height: 14)
                            : Container(
                                key: ValueKey('dot-$day-${done.contains(day) ? 'done' : 'open'}'),
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done.contains(day) ? c.accent : c.soft,
                                  border: day == today
                                      ? Border.all(color: c.ink.withValues(alpha: 0.4))
                                      : null,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              showHabitEditor(context, habit: habit);
            },
            child: const Text('Edit habit'),
          ),
        ],
      ),
    );
  }
}
