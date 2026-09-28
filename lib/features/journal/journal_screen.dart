import 'package:flutter/material.dart';

import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Journal', style: TideType.title(c.ink)),
          const SizedBox(height: 8),
          Text('Your check-ins will gather here, day by day.', style: TideType.body(c.muted)),
        ],
      ),
    );
  }
}
