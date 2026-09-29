import 'package:flutter/material.dart';

import '../checkin/check_in_card.dart';
import '../habits/habit_history_sheet.dart';
import '../habits/habits_card.dart';
import '../tasks/later_screen.dart';
import '../tasks/tasks_card.dart';
import 'daily_note.dart';
import 'inbox_line.dart';
import 'today_header.dart';
import '../../ui/widgets/calm_entry.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          const TodayHeader(),
          const CalmEntry(index: 0, child: DailyNoteView()),
          const SizedBox(height: 24),
          const CalmEntry(index: 1, child: CheckInCard()),
          const SizedBox(height: 12),
          CalmEntry(
            index: 2,
            child: HabitsCard(onLongPress: (habit) => showHabitHistory(context, habit)),
          ),
          const SizedBox(height: 12),
          const CalmEntry(index: 3, child: TasksCard(trailing: LaterLink())),
          const SizedBox(height: 8),
          const CalmEntry(index: 4, child: InboxLine()),
        ],
      ),
    );
  }
}
