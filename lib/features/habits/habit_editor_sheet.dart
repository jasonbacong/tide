import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_icons.dart';

const softHabitLimit = 8;

Future<bool> showHabitEditor(BuildContext context, {Habit? habit}) async {
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
    builder: (_) => HabitEditorSheet(habit: habit),
  );
  return saved ?? false;
}

class HabitEditorSheet extends ConsumerStatefulWidget {
  const HabitEditorSheet({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.habit?.name ?? '');
  late String _icon = widget.habit?.icon ?? habitIcons.keys.first;
  late int _target = widget.habit?.dailyTarget ?? 1;
  String? _error;
  bool _saving = false;
  int _activeCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.habit == null) {
      ref.read(habitRepositoryProvider).activeCount().then((n) {
        if (mounted) setState(() => _activeCount = n);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name first');
      return;
    }
    _saving = true;
    final repo = ref.read(habitRepositoryProvider);
    try {
      final h = widget.habit;
      if (h == null) {
        await repo.add(name: _name.text, icon: _icon, dailyTarget: _target);
      } else {
        await repo.update(h.id,
            name: _name.text, icon: _icon, dailyTarget: _target, goalId: h.goalId);
      }
      _close();
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  Future<void> _archive() async {
    final h = widget.habit!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${h.name}?'),
        content: const Text("It'll disappear from Today. Your history is kept."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(habitRepositoryProvider).archive(h.id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final editing = widget.habit != null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing ? 'Edit habit' : 'New habit', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.sentences,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Read', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (!editing && _activeCount >= softHabitLimit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You already have $_activeCount habits. Keeping it light helps them stick.',
                style: TideType.label(c.muted),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in habitIcons.entries)
                Tooltip(
                  message: entry.key,
                  child: InkResponse(
                    onTap: () => setState(() => _icon = entry.key),
                    radius: 24,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _icon == entry.key ? c.accent : c.background,
                      ),
                      child: Icon(entry.value,
                          size: 20, color: _icon == entry.key ? Colors.white : c.ink),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: 'Fewer',
                onPressed: _target > 1 ? () => setState(() => _target--) : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  _target == 1 ? 'Once a day' : '$_target times a day',
                  textAlign: TextAlign.center,
                  style: TideType.body(c.ink),
                ),
              ),
              IconButton(
                tooltip: 'More',
                onPressed: _target < HabitRepository.maxTarget
                    ? () => setState(() => _target++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: Text(editing ? 'Save' : 'Save habit')),
          if (editing)
            TextButton(onPressed: _archive, child: const Text('Archive habit')),
        ],
      ),
    );
  }
}
