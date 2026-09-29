import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import 'providers.dart';
import 'task_editor_sheet.dart';
import 'task_filter.dart';
import 'task_labels.dart';
import 'task_tile.dart';

class TasksCard extends ConsumerStatefulWidget {
  const TasksCard({super.key, this.trailing});

  /// Header action (the "Later" link, added in Task 5).
  final Widget? trailing;

  @override
  ConsumerState<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends ConsumerState<TasksCard> {
  /// Hidden the moment a row is swiped away, before the stream catches up.
  final _hidden = <String>{};

  /// Order shown immediately after a drag, until the database stream catches up.
  List<String>? _pendingOrder;

  List<Task> _applyPendingOrder(List<Task> open) {
    final pending = _pendingOrder;
    if (pending == null) return open;
    if (open.map((t) => t.id).join(',') == pending.join(',')) {
      _pendingOrder = null; // caught up
      return open;
    }
    int rank(Task t) {
      final i = pending.indexOf(t.id);
      return i < 0 ? pending.length : i;
    }
    return [...open]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Future<void> _add() async {
    final saved = await showTaskEditor(context);
    // Don't let an active filter hide what was just added.
    if (saved && mounted) ref.read(taskFilterProvider.notifier).clear();
  }

  Future<void> _delete(Task task) async {
    final repo = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(task.id));
    await repo.delete(task.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Task deleted'),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.restore(task.id);
            if (mounted) setState(() => _hidden.remove(task.id));
          },
        ),
      ));
  }

  Widget _row(Task task) {
    final c = context.tide;
    final repo = ref.read(taskRepositoryProvider);
    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      direction: DismissDirection.endToStart,
      movementDuration: motion(context, const Duration(milliseconds: 200)),
      resizeDuration: motion(context, const Duration(milliseconds: 300)),
      onDismissed: (_) => _delete(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline, color: c.muted),
      ),
      child: TaskTile(
        task: task,
        onToggle: () => task.isDone ? repo.uncomplete(task.id) : repo.complete(task.id),
        onOpen: () => showTaskEditor(context, task: task),
      ),
    );
  }

  Widget _reorderable(List<Task> tasks) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final t in tasks) t.id];
        ids.insert(newIndex, ids.removeAt(oldIndex));
        setState(() => _pendingOrder = ids);
        ref.read(taskRepositoryProvider).reorder(ids);
      },
      children: [
        for (var i = 0; i < tasks.length; i++)
          ReorderableDelayedDragStartListener(
            key: ValueKey(tasks[i].id),
            index: i,
            child: _row(tasks[i]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final filter = ref.watch(taskFilterProvider);
    final openAsync = ref.watch(todayOpenTasksProvider);
    final doneAsync = ref.watch(todayDoneTasksProvider);
    final loaded = openAsync.hasValue && doneAsync.hasValue;
    final failed = !loaded && (openAsync.hasError || doneAsync.hasError);
    final open = _applyPendingOrder(
        openAsync.listOrEmpty.where((t) => !_hidden.contains(t.id)).toList());
    final done = doneAsync.listOrEmpty.where((t) => !_hidden.contains(t.id)).toList();
    final shown = filterTasks(open, filter);

    Widget hint(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(text, style: TideType.body(c.muted)),
        );

    return TideCard(
      title: 'Tasks',
      trailing: widget.trailing,
      child: AnimatedSize(
        duration: motion(context, Motion.settle),
        curve: Motion.ease,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open.isNotEmpty) _FilterChips(filter: filter),
            if (failed) hint("Couldn't load your tasks."),
            if (loaded && open.isEmpty && done.isEmpty)
              hint('Nothing planned. Add something small.'),
            if (open.isNotEmpty && shown.isEmpty) hint('Nothing matches. Try another filter.'),
            if (shown.isNotEmpty)
              filter.isEmpty ? _reorderable(shown) : Column(children: [for (final t in shown) _row(t)]),
            for (final t in done) KeyedSubtree(key: ValueKey('done-${t.id}'), child: _row(t)),
            InkWell(
              onTap: _add,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.add, size: 22, color: c.muted),
                  ),
                  Text('Add task', style: TideType.body(c.muted)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.filter});

  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final e in Energy.values)
            FilterChip(
              showCheckmark: true,
              label: Text(energyLabel(e)),
              selected: filter.energy == e,
              onSelected: (_) => notifier.toggleEnergy(e),
            ),
          for (final m in const [15, 30])
            FilterChip(
              showCheckmark: true,
              label: Text('≤ $m min'),
              selected: filter.maxMinutes == m,
              onSelected: (_) => notifier.toggleMaxMinutes(m),
            ),
        ],
      ),
    );
  }
}
