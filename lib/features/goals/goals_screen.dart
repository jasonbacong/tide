import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/repositories/goal_repository.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/progress_ring.dart';
import 'goal_editor_sheet.dart';
import 'providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final activeAsync = ref.watch(activeGoalsProvider);
    final active = activeAsync.listOrEmpty;
    final past = ref.watch(pastGoalsProvider).listOrEmpty;

    void newGoal() {
      if (active.length >= GoalRepository.maxActive) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(const GoalLimitReached().toString())));
        return;
      }
      showGoalEditor(context);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Goals', style: TideType.title(c.ink)),
          const SizedBox(height: 16),
          if (activeAsync.hasValue && active.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('What would you like to work towards?', style: TideType.body(c.muted)),
            ),
          if (activeAsync.hasError && !activeAsync.hasValue)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text("Couldn't load your goals.", style: TideType.body(c.muted)),
            ),
          for (final g in active)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: _GoalCard(item: g)),
          InkWell(
            onTap: newGoal,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(children: [
                Icon(Icons.add, color: c.muted),
                const SizedBox(width: 8),
                Text('New goal', style: TideType.body(c.muted)),
              ]),
            ),
          ),
          if (past.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text('Past goals', style: TideType.label(c.muted)),
                children: [for (final p in past) _PastGoalRow(item: p)],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.item});

  final GoalWithProgress item;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final g = item.goal;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/goals/${g.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: TideType.body(c.ink)),
                if (g.targetSeason != null) Text(g.targetSeason!, style: TideType.label(c.muted)),
                if (g.why != null) ...[
                  const SizedBox(height: 6),
                  Text(g.why!,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TideType.label(c.muted)),
                ],
              ]),
            ),
            if (item.progress != null) ...[
              const SizedBox(width: 12),
              ProgressRing(progress: item.progress!, size: 44),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PastGoalRow extends StatelessWidget {
  const _PastGoalRow({required this.item});

  final GoalWithProgress item;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final g = item.goal;
    final when = g.completedAt == null ? '' : ' · ${DateFormat('MMM y').format(g.completedAt!)}';
    final status = g.status == GoalStatus.achieved ? 'Achieved' : 'Let go';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(g.title, style: TideType.body(c.ink)),
      subtitle: Text('$status$when', style: TideType.label(c.muted)),
      onTap: () => context.go('/goals/${g.id}'),
    );
  }
}
