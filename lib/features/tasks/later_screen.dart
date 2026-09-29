import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/async_x.dart';
import '../../data/clock.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'providers.dart';
import 'task_editor_sheet.dart';
import 'task_labels.dart';

/// "Later · 3" link for the Tasks card header.
class LaterLink extends ConsumerWidget {
  const LaterLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(laterTasksProvider).listOrEmpty.length;
    return TextButton(
      onPressed: () => context.go('/today/later'),
      child: Text(count == 0 ? 'Later' : 'Later · $count'),
    );
  }
}

class LaterScreen extends ConsumerWidget {
  const LaterScreen({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref, Task task) async {
    final now = ref.read(nowProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day + 1),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) await ref.read(taskRepositoryProvider).setDate(task.id, dateKey(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final tasks = ref.watch(laterTasksProvider).listOrEmpty;
    return Scaffold(
      appBar: AppBar(title: Text('Later', style: TideType.title(c.ink))),
      body: tasks.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Nothing for later', style: TideType.title(c.ink)),
                const SizedBox(height: 4),
                Text('Tasks without a date wait here.', style: TideType.body(c.muted)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: tasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final task = tasks[i];
                final meta = taskMeta(task);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration:
                      BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => showTaskEditor(context, task: task),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(task.title, style: TideType.body(c.ink)),
                          if (meta.isNotEmpty) Text(meta, style: TideType.label(c.muted)),
                        ]),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pick a date',
                      icon: Icon(Icons.event_outlined, color: c.muted),
                      onPressed: () => _pickDate(context, ref, task),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(taskRepositoryProvider)
                          .setDate(task.id, ref.read(todayKeyProvider)),
                      child: const Text('Do today'),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
