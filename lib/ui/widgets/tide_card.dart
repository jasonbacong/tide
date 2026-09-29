import 'package:flutter/material.dart';

import '../tide_colors.dart';
import '../typography.dart';

/// White (or dark) rounded card from spec §3.4: 18 px radius, 16 px padding, no shadow.
class TideCard extends StatelessWidget {
  const TideCard({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.tide;
    // A Material surface (not a coloured box) so ink ripples inside the card are visible.
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Row(
                children: [
                  Expanded(child: Text(title!, style: TideType.label(c.muted))),
                  ?trailing,
                ],
              ),
            if (title != null) const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
