import 'package:flutter/material.dart';

import '../tasks/later_screen.dart';
import '../tasks/tasks_card.dart';
import 'inbox_line.dart';
import 'today_header.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: const [
          TodayHeader(),
          SizedBox(height: 24),
          TasksCard(trailing: LaterLink()),
          SizedBox(height: 8),
          InboxLine(),
        ],
      ),
    );
  }
}
