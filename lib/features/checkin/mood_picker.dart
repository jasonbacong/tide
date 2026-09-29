import 'package:flutter/material.dart';

import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';

const moodNames = ['Heavy', 'Low', 'Okay', 'Good', 'Bright'];

class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 5; i++)
          Tooltip(
            message: moodNames[i - 1],
            child: InkResponse(
              key: ValueKey('mood-$i'),
              radius: 26,
              onTap: () => onChanged(value == i ? null : i),
              child: AnimatedContainer(
                duration: motion(context, Motion.quick),
                curve: Motion.ease,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TideColors.mood[i - 1].withValues(alpha: value == i ? 1 : 0.35),
                  border: Border.all(
                    color: value == i ? c.ink.withValues(alpha: 0.5) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
