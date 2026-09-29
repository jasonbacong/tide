import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/clock.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.moods,
    required this.today,
    required this.onDayTap,
    this.onPrevious,
    this.onNext,
  });

  final int year;
  final int month;
  final Map<String, int?> moods;
  final String today;
  final ValueChanged<String> onDayTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final first = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(children: [
          Expanded(
            child: Text(DateFormat('MMMM y').format(first), style: TideType.title(c.ink)),
          ),
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final l in letters)
            Expanded(
              child: Text(l, textAlign: TextAlign.center, style: TideType.label(c.muted)),
            ),
        ]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.9,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              () {
                final key = dateKey(DateTime(year, month, d));
                final future = key.compareTo(today) > 0;
                final mood = moods[key];
                return InkResponse(
                  key: ValueKey('cal-$key'),
                  onTap: future ? null : () => onDayTap(key),
                  radius: 20,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$d',
                        style: TideType.label(future ? c.soft : c.ink).copyWith(
                          decoration: key == today ? TextDecoration.underline : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        key: mood == null ? null : ValueKey('dot-$key-$mood'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mood == null
                              ? (moods.containsKey(key) ? c.soft : Colors.transparent)
                              : TideColors.mood[mood - 1],
                        ),
                      ),
                    ],
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}
