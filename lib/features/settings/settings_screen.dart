import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_info.dart';
import '../../data/async_x.dart';
import '../../data/enums.dart';
import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import '../habits/habit_editor_sheet.dart';
import '../habits/habit_icons.dart';
import '../habits/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.backupSection});

  final Widget? backupSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final settings = ref.watch(settingsProvider).value;
    final habits = ref.watch(activeHabitsProvider).listOrEmpty;
    final repo = ref.read(settingsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: TideType.title(c.ink))),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              children: [
                TideCard(
                  title: 'Name',
                  child: AutosaveField(
                    initialValue: settings.name,
                    hint: 'Your first name',
                    onSave: repo.setName,
                  ),
                ),
                const SizedBox(height: 12),
                TideCard(
                  title: 'Habits',
                  trailing: TextButton(
                    onPressed: () => showHabitEditor(context),
                    child: const Text('Add habit'),
                  ),
                  child: habits.isEmpty
                      ? Text('No habits yet.', style: TideType.body(c.muted))
                      : ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorderItem: (oldIndex, newIndex) {
                            final ids = [for (final h in habits) h.id];
                            ids.insert(newIndex, ids.removeAt(oldIndex));
                            ref.read(habitRepositoryProvider).reorder(ids);
                          },
                          children: [
                            for (final h in habits)
                              ListTile(
                                key: ValueKey(h.id),
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(iconFor(h.icon), color: c.accent),
                                title: Text(h.name, style: TideType.body(c.ink)),
                                subtitle: Text(
                                  h.dailyTarget == 1
                                      ? 'Once a day'
                                      : '${h.dailyTarget} times a day',
                                  style: TideType.label(c.muted),
                                ),
                                onTap: () => showHabitEditor(context, habit: h),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                TideCard(
                  title: 'Appearance',
                  child: SegmentedButton<ThemePreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemePreference.system, label: Text('System')),
                      ButtonSegment(value: ThemePreference.light, label: Text('Light')),
                      ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
                    ],
                    selected: {settings.theme},
                    onSelectionChanged: (s) => repo.setTheme(s.first),
                  ),
                ),
                if (backupSection != null) ...[const SizedBox(height: 12), backupSection!],
                const SizedBox(height: 12),
                TideCard(
                  title: 'About',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tide $appVersion', style: TideType.body(c.ink)),
                    const SizedBox(height: 4),
                    Text('Everything stays on this phone unless you export it.',
                        style: TideType.label(c.muted)),
                  ]),
                ),
              ],
            ),
    );
  }
}
