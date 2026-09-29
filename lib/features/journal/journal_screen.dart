import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/async_x.dart';
import '../../data/providers.dart';
import '../../data/repositories/check_in_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/tide_card.dart';
import '../checkin/mood_picker.dart';
import '../checkin/providers.dart';
import 'month_calendar.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  late DateTime _month;
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowProvider);
    _month = DateTime(now.year, now.month);
  }

  void _onDayTap(String date, List<CheckIn> entries) {
    final key = _keys[date];
    if (entries.any((e) => e.date == date) && key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: motion(context, Motion.settle), curve: Motion.ease);
    } else {
      context.go('/journal/$date');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final now = ref.watch(nowProvider);
    final entries = ref.watch(journalEntriesProvider).listOrEmpty;
    final moods = switch (ref.watch(monthMoodsProvider((_month.year, _month.month)))) {
      AsyncData(:final value) => value,
      _ => const <String, int?>{},
    };
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Journal', style: TideType.title(c.ink)),
          const SizedBox(height: 16),
          TideCard(
            child: MonthCalendar(
              year: _month.year,
              month: _month.month,
              moods: moods,
              today: today,
              onDayTap: (d) => _onDayTap(d, entries),
              onPrevious: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              onNext: isCurrentMonth
                  ? null
                  : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text('Your check-ins will gather here, day by day.', style: TideType.body(c.muted)),
          for (final e in entries)
            Padding(
              key: _keys.putIfAbsent(e.date, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: 12),
              child: _EntryCard(entry: e),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final CheckIn entry;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/journal/${entry.date}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(DateFormat('EEEE, d MMM').format(DateTime.parse(entry.date)),
                      style: TideType.label(c.muted)),
                ),
                if (entry.mood != null)
                  Tooltip(
                    message: moodNames[entry.mood! - 1],
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: TideColors.mood[entry.mood! - 1]),
                    ),
                  ),
              ]),
              if (entry.intention != null) ...[
                const SizedBox(height: 8),
                Text(entry.intention!, style: TideType.note(c.muted)),
              ],
              if (entry.reflection != null) ...[
                const SizedBox(height: 8),
                Text(entry.reflection!, style: TideType.body(c.ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
