import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/async_x.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'providers.dart';

class GoalPicker extends ConsumerWidget {
  const GoalPicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final goals = ref.watch(activeGoalsProvider).listOrEmpty;
    final titles = ref.watch(goalTitlesProvider).value ?? const <String, String>{};
    // A link to a past goal still needs a chip, so it can be removed.
    final pastLink = value != null && !goals.any((g) => g.goal.id == value) ? titles[value] : null;
    if (goals.isEmpty && pastLink == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Goal', style: TideType.label(c.muted)),
        ),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (pastLink != null)
            ChoiceChip(label: Text(pastLink), selected: true, onSelected: (_) => onChanged(null)),
          for (final g in goals)
            ChoiceChip(
              label: Text(g.goal.title),
              selected: value == g.goal.id,
              onSelected: (_) => onChanged(value == g.goal.id ? null : g.goal.id),
            ),
        ]),
      ]),
    );
  }
}
