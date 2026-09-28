import 'package:flutter/material.dart';

import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: [
          Text('Goals', style: TideType.title(c.ink)),
          const SizedBox(height: 8),
          Text('A few things you are working towards will live here.',
              style: TideType.body(c.muted)),
        ],
      ),
    );
  }
}
