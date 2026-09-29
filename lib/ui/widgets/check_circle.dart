import 'package:flutter/material.dart';

/// Round check used by tasks and milestones: a ring that fills and shows a tick at 1.
class CheckCircle extends StatelessWidget {
  const CheckCircle({super.key, required this.fill, required this.ring, required this.color});

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
