import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'greeting.dart';

class TodayHeader extends ConsumerWidget {
  const TodayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final period = ref.watch(dayPeriodProvider);
    final c = context.tide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE, d MMM').format(now), style: TideType.label(c.muted)),
        const SizedBox(height: 4),
        // Name is wired to settings in Milestone 5 (onboarding).
        Text(greetingFor(period, ''), style: TideType.greeting(c.ink)),
      ],
    );
  }
}
