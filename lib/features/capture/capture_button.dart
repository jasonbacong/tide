import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/motion.dart';
import 'capture_sheet.dart';

class CaptureButton extends StatefulWidget {
  const CaptureButton({super.key});

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton> {
  bool _open = false;

  Future<void> _capture() async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _open = true);
    final saved = await showCaptureSheet(context);
    if (!mounted) return;
    setState(() => _open = false);
    if (saved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Saved to your inbox'),
          duration: Duration(seconds: 2),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _capture,
      tooltip: 'Capture a thought',
      child: AnimatedRotation(
        turns: _open ? 0.125 : 0,
        duration: motion(context, Motion.sheet),
        curve: Motion.ease,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
