import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/async_x.dart';
import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import 'habit_circle.dart';
import 'habit_editor_sheet.dart';
import 'providers.dart';

class HabitsCard extends ConsumerStatefulWidget {
  const HabitsCard({super.key, this.onLongPress});

  final void Function(Habit habit)? onLongPress;

  @override
  ConsumerState<HabitsCard> createState() => _HabitsCardState();
}

class _HabitsCardState extends ConsumerState<HabitsCard> {
  String? _caption;
  Timer? _captionTimer;

  @override
  void dispose() {
    _captionTimer?.cancel();
    super.dispose();
  }

  Future<void> _tap(HabitToday item) async {
    HapticFeedback.lightImpact();
    final next = await ref
        .read(habitRepositoryProvider)
        .tap(item.habit.id, ref.read(todayKeyProvider));
    final target = item.habit.dailyTarget;
    if (next >= target) HapticFeedback.mediumImpact();
    if (target > 1 && mounted) {
      _captionTimer?.cancel();
      setState(() => _caption = '${item.habit.name} ${next.clamp(0, target)} of $target');
      _captionTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _caption = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final habits = ref.watch(todayHabitsProvider).listOrEmpty;
    return TideCard(
      title: 'Habits',
      trailing: IconButton(
        tooltip: 'Add habit',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.add, color: c.muted),
        onPressed: () => showHabitEditor(context),
      ),
      child: habits.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text("Add a habit or two you'd like to keep.",
                  style: TideType.body(c.muted)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final item in habits)
                      HabitCircle(
                        key: ValueKey('habit-${item.habit.id}'),
                        item: item,
                        onTap: () => _tap(item),
                        onLongPress: widget.onLongPress == null
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                widget.onLongPress!(item.habit);
                              },
                      ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: motion(context, Motion.quick),
                  child: _caption == null
                      ? const SizedBox(height: 8)
                      : Padding(
                          key: ValueKey(_caption),
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_caption!, style: TideType.label(c.muted)),
                        ),
                ),
              ],
            ),
    );
  }
}
