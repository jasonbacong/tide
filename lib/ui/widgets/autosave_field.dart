import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tide_colors.dart';
import '../typography.dart';

/// Borderless text that saves itself 600 ms after typing stops (spec §4.4).
class AutosaveField extends StatefulWidget {
  const AutosaveField({
    super.key,
    required this.initialValue,
    required this.onSave,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.style,
  });

  final String? initialValue;
  final Future<void> Function(String value) onSave;
  final String hint;
  final int minLines;
  final int maxLines;
  final TextStyle? style;

  @override
  State<AutosaveField> createState() => _AutosaveFieldState();
}

class _AutosaveFieldState extends State<AutosaveField> {
  static const _debounceDelay = Duration(milliseconds: 600);

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  late String _lastSaved = (widget.initialValue ?? '').trim();
  Timer? _debounce;
  Timer? _savedTimer;
  bool _showSaved = false;
  String? _error;

  void _changed(String _) {
    if (_error != null) setState(() => _error = null);
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _flush);
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    _debounce = null;
    final value = _controller.text;
    if (value.trim() == _lastSaved) return;
    _lastSaved = value.trim();
    try {
      await widget.onSave(value);
      if (!mounted) return;
      setState(() => _showSaved = true);
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showSaved = false);
      });
    } catch (_) {
      _lastSaved = '\u0000'; // force a retry on the next change
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      final value = _controller.text;
      if (value.trim() != _lastSaved) widget.onSave(value);
    }
    _savedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textCapitalization: TextCapitalization.sentences,
          style: widget.style ?? TideType.body(c.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: false,
            border: InputBorder.none,
            isCollapsed: true,
            errorText: _error,
          ),
          onChanged: _changed,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedOpacity(
            key: const ValueKey('saved-label'),
            opacity: _showSaved ? 1 : 0,
            duration: motion(context, Motion.quick),
            child: Text('Saved', style: TideType.label(c.muted)),
          ),
        ),
      ],
    );
  }
}
