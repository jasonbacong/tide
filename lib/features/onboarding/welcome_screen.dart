import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../habits/habit_icons.dart';

/// Suggested starter habits (spec §2.6): label, name, icon, daily target.
const _suggestions = [
  ('Read', 'Read', 'book', 1),
  ('Drink water', 'Water', 'water', 8),
  ('Move', 'Move', 'run', 1),
];

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.footer});

  /// Extra action under Start ("Restore from a backup", added with backups).
  final Widget? footer;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  final _picked = <String>{};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Type your first name');
      return;
    }
    _saving = true;
    try {
      final habits = ref.read(habitRepositoryProvider);
      for (final (label, name, icon, target) in _suggestions) {
        if (_picked.contains(label)) await habits.add(name: name, icon: icon, dailyTarget: target);
      }
      // Name last: saving it switches the app from Welcome to Today.
      await ref.read(settingsRepositoryProvider).setName(_name.text);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          children: [
            Text('Welcome to Tide', style: TideType.greeting(c.ink)),
            const SizedBox(height: 8),
            Text('A calm place for your day.', style: TideType.body(c.muted)),
            const SizedBox(height: 40),
            Text('What should we call you?', style: TideType.label(c.muted)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TideType.body(c.ink),
              decoration: InputDecoration(hintText: 'Your first name', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 28),
            Text('A few habits to start with (optional)', style: TideType.label(c.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (label, _, icon, _) in _suggestions)
                FilterChip(
                  avatar: Icon(iconFor(icon), size: 18),
                  label: Text(label),
                  selected: _picked.contains(label),
                  onSelected: (on) =>
                      setState(() => on ? _picked.add(label) : _picked.remove(label)),
                ),
            ]),
            const SizedBox(height: 40),
            FilledButton(onPressed: _start, child: const Text('Start')),
            ?widget.footer,
          ],
        ),
      ),
    );
  }
}
