import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/repositories/habit_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'habit_icons.dart';

class HabitCircle extends StatefulWidget {
  const HabitCircle({super.key, required this.item, required this.onTap, this.onLongPress});

  final HabitToday item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<HabitCircle> createState() => _HabitCircleState();
}

class _HabitCircleState extends State<HabitCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this);

  @override
  void didUpdateWidget(HabitCircle old) {
    super.didUpdateWidget(old);
    if (!old.item.done && widget.item.done) {
      _ripple.duration = motion(context, Motion.ripple);
      _ripple.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final item = widget.item;
    final target = item.habit.dailyTarget;
    final progress = item.shown / target;
    const size = 52.0;
    return Semantics(
      button: true,
      label: target == 1
          ? '${item.habit.name}, ${item.done ? 'done' : 'not done'}'
          : '${item.habit.name}, ${item.shown} of $target',
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _ripple,
                      builder: (context, _) => _ripple.isAnimating
                          ? Transform.scale(
                              scale: 1 + 0.8 * Motion.ease.transform(_ripple.value),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.accent.withValues(alpha: 0.6 * (1 - _ripple.value)),
                                    width: 2,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: progress),
                      duration: motion(context, Motion.ringFill),
                      curve: Motion.ease,
                      builder: (context, value, _) => CustomPaint(
                        size: const Size.square(size),
                        painter: _RingPainter(
                          progress: value,
                          segments: target,
                          track: c.soft,
                          color: c.accent,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: item.done ? 1 : 0,
                      duration: motion(context, Motion.bloom),
                      curve: Motion.ease,
                      child: Container(
                        width: size - 6,
                        height: size - 6,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                    ),
                    Icon(iconFor(item.habit.icon),
                        size: 22, color: item.done ? Colors.white : c.accent),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TideType.label(c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Track plus progress arc; split into [segments] with small gaps when segments > 1.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.segments,
    required this.track,
    required this.color,
  });

  final double progress;
  final int segments;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final gap = segments > 1 ? 0.12 : 0.0;
    final sweepEach = (2 * math.pi) / segments;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final filled = progress * segments;
    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * sweepEach + gap / 2;
      final sweep = sweepEach - gap;
      canvas.drawArc(arcRect, start, sweep, false, trackPaint);
      final part = (filled - i).clamp(0.0, 1.0);
      if (part > 0) canvas.drawArc(arcRect, start, sweep * part, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.color != color ||
      old.track != track;
}
