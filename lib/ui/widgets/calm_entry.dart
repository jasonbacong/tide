import 'package:flutter/widgets.dart';

import '../motion.dart';

/// Fade in and rise 8 px, staggered by [index] (spec §3.5).
class CalmEntry extends StatefulWidget {
  const CalmEntry({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<CalmEntry> createState() => _CalmEntryState();
}

class _CalmEntryState extends State<CalmEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Animation<double> _t = const AlwaysStoppedAnimation(0);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final delay = Motion.stagger * widget.index;
    final total = motion(context, Motion.quick + delay);
    if (total == Duration.zero) {
      _c.value = 1;
      _t = const AlwaysStoppedAnimation(1);
      return;
    }
    _c.duration = total;
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Motion.ease));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(offset: Offset(0, 8 * (1 - _t.value)), child: child),
        ),
        child: widget.child,
      );
}
