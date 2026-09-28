import 'package:flutter/material.dart';

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
        ],
      ),
    );
  }
}
