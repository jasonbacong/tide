import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import 'mood_picker.dart';
import 'providers.dart';

/// Intention before 17:00, Reflection from 17:00 (spec §4.4).
class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key});

  static const reflectionHour = 17;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    final evening = ref.watch(nowProvider).hour >= reflectionHour;
    final repo = ref.read(checkInRepositoryProvider);
    final checkIn = ref.watch(checkInForDayProvider(today));

    return switch (checkIn) {
      AsyncData(:final value) => evening
          ? TideCard(
              title: 'Reflection',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value?.intention != null) ...[
                    Text('This morning: ${value!.intention}', style: TideType.note(c.muted)),
                    const SizedBox(height: 12),
                  ],
                  MoodPicker(
                    value: value?.mood,
                    onChanged: (m) => repo.saveMood(today, m),
                  ),
                  const SizedBox(height: 12),
                  AutosaveField(
                    key: ValueKey('reflection-$today'),
                    initialValue: value?.reflection,
                    hint: 'How was today?',
                    minLines: 3,
                    maxLines: 6,
                    onSave: (v) => repo.saveReflection(today, v),
                  ),
                ],
              ),
            )
          : TideCard(
              title: 'Intention',
              child: AutosaveField(
                key: ValueKey('intention-$today'),
                initialValue: value?.intention,
                hint: 'What would make today good?',
                onSave: (v) => repo.saveIntention(today, v),
              ),
            ),
      // Riverpod retries failed loads, so the error can arrive while "loading".
      _ when checkIn.hasError => TideCard(
          title: evening ? 'Reflection' : 'Intention',
          child: Text("Couldn't load today's check-in.", style: TideType.body(c.muted)),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
