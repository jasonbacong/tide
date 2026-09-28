import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';

Future<bool> showCaptureSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: motion(context, Motion.sheet),
      reverseDuration: motion(context, Motion.quick),
    ),
    builder: (_) => const CaptureSheet(),
  );
  return saved ?? false;
}

class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key});

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Type something first');
      return;
    }
    _saving = true;
    try {
      await ref.read(captureRepositoryProvider).add(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _saving = false;
      if (mounted) setState(() => _error = "Couldn't save that. Try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Capture a thought', style: TideType.label(c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TideType.body(c.ink),
            decoration: InputDecoration(hintText: 'Book a table for Friday', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save to inbox')),
        ],
      ),
    );
  }
}
