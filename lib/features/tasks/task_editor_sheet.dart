import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/clock.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'task_labels.dart';

Future<bool> showTaskEditor(BuildContext context, {Task? task, String? initialTitle}) async {
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
    builder: (_) => TaskEditorSheet(task: task, initialTitle: initialTitle),
  );
  return saved ?? false;
}

enum _When { today, later, date }

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, this.task, this.initialTitle});

  final Task? task;
  final String? initialTitle;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? widget.initialTitle ?? '');
  Energy? _energy;
  int? _minutes;
  _When _when = _When.today;
  String? _pickedDate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t == null) return;
    _energy = t.energy;
    _minutes = t.minutes;
    final today = ref.read(todayKeyProvider);
    if (t.date == null) {
      _when = _When.later;
    } else if (t.date == today) {
      _when = _When.today;
    } else {
      _when = _When.date;
      _pickedDate = t.date;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(nowProvider);
    final initial =
        _pickedDate != null ? DateTime.parse(_pickedDate!) : DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) {
      setState(() {
        _when = _When.date;
        _pickedDate = dateKey(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give it a name first');
      return;
    }
    _saving = true;
    final repo = ref.read(taskRepositoryProvider);
    final date = switch (_when) {
      _When.today => ref.read(todayKeyProvider),
      _When.later => null,
      _When.date => _pickedDate,
    };
    try {
      final existing = widget.task;
      if (existing == null) {
        await repo.add(title: _title.text, energy: _energy, minutes: _minutes, date: date);
      } else {
        await repo.update(existing.id,
            title: _title.text,
            energy: _energy,
            minutes: _minutes,
            date: date,
            goalId: existing.goalId);
      }
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop(true);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text, style: TideType.label(c.muted)),
        );
    final dateChipLabel = _when == _When.date && _pickedDate != null
        ? DateFormat('EEE, d MMM').format(DateTime.parse(_pickedDate!))
        : 'Pick a date';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.task == null ? 'New task' : 'Edit task', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            autofocus: widget.task == null,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Call the dentist', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          label('Energy'),
          Wrap(spacing: 8, children: [
            for (final e in Energy.values)
              ChoiceChip(
                label: Text(energyLabel(e)),
                selected: _energy == e,
                onSelected: (_) => setState(() => _energy = _energy == e ? null : e),
              ),
          ]),
          const SizedBox(height: 12),
          label('Time'),
          Wrap(spacing: 8, children: [
            for (final m in taskMinuteOptions)
              ChoiceChip(
                label: Text(minutesLabel(m)),
                selected: _minutes == m,
                onSelected: (_) => setState(() => _minutes = _minutes == m ? null : m),
              ),
          ]),
          const SizedBox(height: 12),
          label('When'),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: _when == _When.today,
              onSelected: (_) => setState(() => _when = _When.today),
            ),
            ChoiceChip(
              label: const Text('Later'),
              selected: _when == _When.later,
              onSelected: (_) => setState(() => _when = _When.later),
            ),
            ChoiceChip(
              label: Text(dateChipLabel),
              selected: _when == _When.date,
              onSelected: (_) => _pickDate(),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: Text(widget.task == null ? 'Save task' : 'Save'),
          ),
        ],
      ),
    );
  }
}
