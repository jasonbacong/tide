import 'package:flutter/material.dart';

import '../checkin/check_in_card.dart';
import '../habits/habit_history_sheet.dart';
import '../habits/habits_card.dart';
import '../tasks/later_screen.dart';
import '../tasks/tasks_card.dart';
import 'daily_note.dart';
import 'inbox_line.dart';
import 'today_header.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          const TodayHeader(),
          const DailyNoteView(),
          const SizedBox(height: 24),
          const CheckInCard(),
          const SizedBox(height: 12),
          HabitsCard(onLongPress: (habit) => showHabitHistory(context, habit)),
          const SizedBox(height: 12),
          const TasksCard(trailing: LaterLink()),
          const SizedBox(height: 8),
          const InboxLine(),
        ],
      ),
    );
  }
}
