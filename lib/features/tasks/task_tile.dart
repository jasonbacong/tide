import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/task_repository.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import 'task_labels.dart';

class TaskTile extends StatefulWidget {
  const TaskTile({super.key, required this.task, required this.onToggle, required this.onOpen});

  final Task task;
  final Future<void> Function() onToggle;
  final VoidCallback onOpen;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  static const _fillPart = Interval(0, 0.47, curve: Motion.ease);
  static const _strikePart = Interval(0.47, 1, curve: Motion.ease);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    HapticFeedback.lightImpact();
    if (widget.task.isDone) {
      await widget.onToggle();
      return;
    }
    if (_c.isAnimating || _c.value == 1) return;
    _c.duration = motion(context, Motion.taskCheck + Motion.strike);
    await _c.forward(from: 0);
    await widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    final task = widget.task;
    final meta = taskMeta(task);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final fill = task.isDone ? 1.0 : _fillPart.transform(_c.value);
        final strike = task.isDone ? 1.0 : _strikePart.transform(_c.value);
        final ink = Color.lerp(c.ink, c.muted, strike)!;
        return Row(
          children: [
            InkResponse(
              key: ValueKey('check-${task.id}'),
              onTap: _toggle,
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _CheckCircle(fill: fill, ring: c.warm, color: c.accent),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: widget.onOpen,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StrikeText(task.title, progress: strike, style: TideType.body(ink)),
                      if (meta.isNotEmpty) Text(meta, style: TideType.label(c.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.fill, required this.ring, required this.color});

  final double fill;
  final Color ring;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: fill > 0 ? color : ring, width: 2),
      ),
      alignment: Alignment.center,
      child: Transform.scale(
        scale: fill,
        child: Container(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: fill == 1 ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        ),
      ),
    );
  }
}

/// Single-line text with a strike line drawn left-to-right as [progress] goes 0 → 1.
class StrikeText extends StatelessWidget {
  const StrikeText(this.text, {super.key, required this.progress, required this.style});

  final String text;
  final double progress;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        ellipsis: '…',
        textDirection: Directionality.of(context),
      )..layout(maxWidth: constraints.maxWidth);
      final width = painter.width;
      painter.dispose();
      return CustomPaint(
        foregroundPainter: _StrikePainter(progress: progress, width: width, color: style.color!),
        child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    });
  }
}

class _StrikePainter extends CustomPainter {
  _StrikePainter({required this.progress, required this.width, required this.color});

  final double progress;
  final double width;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(width * progress, y),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      old.progress != progress || old.width != width || old.color != color;
}
