import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/goal_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/check_circle.dart';
import '../../ui/widgets/progress_ring.dart';
import '../../ui/widgets/tide_card.dart';
import '../habits/habit_icons.dart';
import '../tasks/task_tile.dart' show StrikeText;
import 'goal_editor_sheet.dart';
import 'providers.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final _newMilestone = TextEditingController();
  final _hidden = <String>{};
  List<String>? _pendingOrder;
  bool _celebrating = false;
  bool _leaving = false;

  @override
  void dispose() {
    _newMilestone.dispose();
    super.dispose();
  }

  GoalRepository get _repo => ref.read(goalRepositoryProvider);

  /// Close only this screen, and only if it is still the top of its navigator
  /// (the user may have gone back or switched tabs during the celebration).
  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  List<Milestone> _applyPendingOrder(List<Milestone> ms) {
    final pending = _pendingOrder;
    if (pending == null) return ms;
    if (ms.map((m) => m.id).join(',') == pending.join(',')) {
      _pendingOrder = null;
      return ms;
    }
    int rank(Milestone m) {
      final i = pending.indexOf(m.id);
      return i < 0 ? pending.length : i;
    }
    return [...ms]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Future<void> _addMilestone() async {
    final text = _newMilestone.text;
    if (text.trim().isEmpty) return;
    _newMilestone.clear();
    await _repo.addMilestone(widget.goalId, text);
  }

  Future<void> _achieve() async {
    if (_leaving) return;
    _leaving = true;
    HapticFeedback.mediumImpact();
    setState(() => _celebrating = true);
    await Future<void>.delayed(motion(context, Motion.bloom * 2));
    await _repo.markAchieved(widget.goalId);
    _close();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _letGo() async {
    if (_leaving) return;
    if (!await _confirm('Let this goal go?', 'It moves to Past goals. Nothing is deleted.', 'Let it go')) {
      return;
    }
    _leaving = true;
    await _repo.letGo(widget.goalId);
    _close();
  }

  Future<void> _delete() async {
    if (_leaving) return;
    if (!await _confirm('Delete this goal?',
        'Its milestones go too. Linked habits and tasks stay, just unlinked.', 'Delete')) {
      return;
    }
    _leaving = true;
    await _repo.delete(widget.goalId);
    _close();
  }

  Future<void> _deleteMilestone(Milestone m) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(m.id));
    await _repo.deleteMilestone(m.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Milestone removed'),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _repo.restoreMilestone(m.id);
            if (mounted) setState(() => _hidden.remove(m.id));
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final goal = ref.watch(goalProvider(widget.goalId));
    return switch (goal) {
      AsyncData(value: final g?) => _content(context, c, g),
      AsyncData() => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('This goal is no longer here.', style: TideType.body(c.muted))),
        ),
      _ when goal.hasError => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text("Couldn't load this goal.", style: TideType.body(c.muted))),
        ),
      _ => Scaffold(appBar: AppBar()),
    };
  }

  Widget _content(BuildContext context, TideColors c, Goal g) {
    final milestones = _applyPendingOrder(ref
        .watch(milestonesProvider(g.id))
        .listOrEmpty
        .where((m) => !_hidden.contains(m.id))
        .toList());
    final habitsAsync = ref.watch(linkedHabitsProvider(g.id));
    final tasksAsync = ref.watch(linkedTasksProvider(g.id));
    final linkedLoaded = habitsAsync.hasValue && tasksAsync.hasValue;
    final habits = habitsAsync.listOrEmpty;
    final tasks = tasksAsync.listOrEmpty;
    final done = milestones.where((m) => m.done).length;
    final progress = milestones.isEmpty ? null : done / milestones.length;

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          tooltip: 'Edit goal',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showGoalEditor(context, goal: g),
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) => v == 'delete' ? _delete() : null,
          itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('Delete goal'))],
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: TideType.greeting(c.ink)),
                if (g.targetSeason != null) Text(g.targetSeason!, style: TideType.label(c.muted)),
              ]),
            ),
            if (progress != null || _celebrating)
              AnimatedScale(
                scale: _celebrating ? 1.08 : 1,
                duration: motion(context, Motion.bloom),
                curve: Motion.ease,
                child: ProgressRing(progress: _celebrating ? 1 : progress!, size: 64, stroke: 5),
              ),
          ]),
          const SizedBox(height: 16),
          if (g.why != null) ...[
            TideCard(title: 'Why', child: Text(g.why!, style: TideType.body(c.ink))),
            const SizedBox(height: 12),
          ],
          TideCard(
            title: 'Milestones',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) =>
                    Material(color: Colors.transparent, child: child),
                onReorderItem: (oldIndex, newIndex) {
                  final ids = [for (final m in milestones) m.id];
                  ids.insert(newIndex, ids.removeAt(oldIndex));
                  setState(() => _pendingOrder = ids);
                  _repo.reorderMilestones(ids);
                },
                children: [
                  for (var i = 0; i < milestones.length; i++)
                    ReorderableDelayedDragStartListener(
                      key: ValueKey(milestones[i].id),
                      index: i,
                      child: Dismissible(
                        key: ValueKey('dismiss-${milestones[i].id}'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteMilestone(milestones[i]),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.delete_outline, color: c.muted),
                        ),
                        child: Row(children: [
                          InkResponse(
                            key: ValueKey('milestone-${milestones[i].id}'),
                            radius: 22,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _repo.toggleMilestone(milestones[i].id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: CheckCircle(
                                  fill: milestones[i].done ? 1 : 0, ring: c.warm, color: c.accent),
                            ),
                          ),
                          Expanded(
                            child: StrikeText(
                              milestones[i].title,
                              progress: milestones[i].done ? 1 : 0,
                              style: TideType.body(milestones[i].done ? c.muted : c.ink),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _newMilestone,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                style: TideType.body(c.ink),
                decoration: const InputDecoration(hintText: 'Add a milestone'),
                onSubmitted: (_) => _addMilestone(),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          TideCard(
            title: 'Linked',
            child: habits.isEmpty && tasks.isEmpty
                ? (linkedLoaded
                    ? Text('Link habits and tasks to this goal from their editors.',
                        style: TideType.body(c.muted))
                    : const SizedBox(height: 20))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (habits.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final h in habits)
                          Chip(avatar: Icon(iconFor(h.icon), size: 18), label: Text(h.name)),
                      ]),
                    if (habits.isNotEmpty && tasks.isNotEmpty) const SizedBox(height: 8),
                    for (final t in tasks)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(t.title, style: TideType.body(c.ink)),
                      ),
                  ]),
          ),
          const SizedBox(height: 24),
          if (g.isActive) ...[
            FilledButton(onPressed: _achieve, child: const Text('Mark achieved')),
            TextButton(onPressed: _letGo, child: const Text('Let it go')),
          ] else
            Text(
              '${g.status == GoalStatus.achieved ? 'Achieved' : 'Let go'} in '
              '${DateFormat('MMMM y').format(g.completedAt ?? ref.read(nowProvider))}',
              textAlign: TextAlign.center,
              style: TideType.label(c.muted),
            ),
        ],
      ),
    );
  }
}
