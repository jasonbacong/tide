import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/goal_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

Future<bool> showGoalEditor(BuildContext context, {Goal? goal}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    // Above the tab shell's + button and bottom bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, Motion.sheet),
      reverseDuration: motion(context, Motion.quick),
    ),
    builder: (_) => _GoalEditorSheet(goal: goal),
  );
  return saved ?? false;
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.goal});

  final Goal? goal;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final _why = TextEditingController(text: widget.goal?.why ?? '');
  late final _season = TextEditingController(text: widget.goal?.targetSeason ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    _season.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name first');
      return;
    }
    _saving = true;
    final repo = ref.read(goalRepositoryProvider);
    try {
      final g = widget.goal;
      if (g == null) {
        await repo.create(title: _title.text, why: _why.text, targetSeason: _season.text);
      } else {
        await repo.update(g.id, title: _title.text, why: _why.text, targetSeason: _season.text);
      }
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
    } on GoalLimitReached catch (e) {
      _saving = false;
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.goal == null ? 'New goal' : 'Edit goal', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            autofocus: widget.goal == null,
            textCapitalization: TextCapitalization.sentences,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Read 12 books this year', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _why,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: TideType.body(c.ink),
            decoration: const InputDecoration(hintText: 'Why it matters to you'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _season,
            style: TideType.body(c.ink),
            decoration: const InputDecoration(hintText: 'By when, roughly (by spring)'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: Text(widget.goal == null ? 'Save goal' : 'Save')),
        ],
      ),
    );
  }
}
