import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/motion.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../capture/providers.dart';

String inboxLabel(int count) =>
    count == 1 ? '1 thought in your inbox' : '$count thoughts in your inbox';

class InboxLine extends ConsumerWidget {
  const InboxLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = switch (ref.watch(inboxCountProvider)) {
      AsyncData(:final value) => value,
      _ => 0,
    };
    final c = context.tide;
    return AnimatedSwitcher(
      duration: motion(context, Motion.quick),
      switchInCurve: Motion.ease,
      child: count == 0
          ? const SizedBox.shrink()
          : InkWell(
              key: const ValueKey('inbox-line'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go('/today/inbox'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, size: 18, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(inboxLabel(count), style: TideType.body(c.ink))),
                    Icon(Icons.chevron_right, size: 20, color: c.muted),
                  ],
                ),
              ),
            ),
    );
  }
}
