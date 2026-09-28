import 'package:flutter/widgets.dart';

/// Motion tokens from spec §3.5. Soft ease-out, no overshoot.
abstract final class Motion {
  static const quick = Duration(milliseconds: 250);
  static const stagger = Duration(milliseconds: 60);
  static const sheet = Duration(milliseconds: 380);
  static const crossfade = Duration(milliseconds: 600);
  static const ringFill = Duration(milliseconds: 600);
  static const bloom = Duration(milliseconds: 500);
  static const ripple = Duration(milliseconds: 900);
  static const taskCheck = Duration(milliseconds: 350);
  static const strike = Duration(milliseconds: 400);
  static const settle = Duration(milliseconds: 450);
  static const ease = Cubic(0.3, 0.7, 0.2, 1.0);
}

/// Returns [duration], or zero when the system asks for reduced motion.
Duration motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
