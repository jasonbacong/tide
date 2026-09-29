import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/capture_repository.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../data/async_x.dart';
import '../../data/repositories/goal_repository.dart';
import '../goals/providers.dart';
import '../tasks/task_editor_sheet.dart';
import 'providers.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  /// Hidden locally the moment a tile is dismissed, before the DB stream catches up,
  /// so a dismissed Dismissible is never rebuilt.
  final _hidden = <String>{};

  Future<void> _archive(Capture capture) async {
    final repo = ref.read(captureRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(capture.id));
    await repo.archive(capture.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Archived'),
        duration: const Duration(seconds: 4),
        // A snackbar with an action persists by default; the spec wants it gone after 4 s.
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.unarchive(capture.id);
            if (mounted) setState(() => _hidden.remove(capture.id));
          },
        ),
      ));
  }

  Future<void> _makeTask(Capture capture, {String? goalId}) async {
    final repo = ref.read(captureRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final saved =
        await showTaskEditor(context, initialTitle: capture.body, initialGoalId: goalId);
    if (!saved) return;
    if (mounted) setState(() => _hidden.add(capture.id));
    await repo.markConverted(capture.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Task added'), duration: Duration(seconds: 2)));
  }

  Future<void> _openActions(Capture capture) async {
    final goals = ref.read(activeGoalsProvider).listOrEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_task),
            title: const Text('Make task'),
            onTap: () => Navigator.pop(context, 'task'),
          ),
          if (goals.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Link to goal'),
              onTap: () => Navigator.pop(context, 'goal'),
            ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archive'),
            onTap: () => Navigator.pop(context, 'archive'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'task':
        await _makeTask(capture);
      case 'goal':
        await _linkToGoal(capture, goals);
      case 'archive':
        await _archive(capture);
    }
  }

  Future<void> _linkToGoal(Capture capture, List<GoalWithProgress> goals) async {
    final goalId = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final g in goals)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(g.goal.title),
              onTap: () => Navigator.pop(context, g.goal.id),
            ),
        ]),
      ),
    );
    if (goalId == null || !mounted) return;
    await _makeTask(capture, goalId: goalId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final inbox = ref.watch(inboxProvider);
    // Keep goals loaded here: the Goals tab may never have been opened this session.
    ref.watch(activeGoalsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Inbox', style: TideType.title(c.ink))),
      body: switch (inbox) {
        AsyncData(:final value) => _list(value.where((x) => !_hidden.contains(x.id)).toList()),
        AsyncError() =>
          Center(child: Text("Couldn't load your inbox.", style: TideType.body(c.muted))),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _list(List<Capture> captures) {
    final c = context.tide;
    if (captures.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 32, color: c.muted),
            const SizedBox(height: 12),
            Text('Nothing to sort', style: TideType.title(c.ink)),
            const SizedBox(height: 4),
            Text('Anything you capture with + lands here.', style: TideType.body(c.muted)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: captures.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final capture = captures[i];
        return Dismissible(
          key: ValueKey(capture.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _archive(capture),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.archive_outlined, color: c.muted),
          ),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openActions(capture),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      capture.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TideType.body(c.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.add_task, size: 20, color: c.muted),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
