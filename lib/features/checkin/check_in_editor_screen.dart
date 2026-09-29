import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../ui/tide_colors.dart';
import '../../ui/typography.dart';
import '../../ui/widgets/autosave_field.dart';
import '../../ui/widgets/tide_card.dart';
import 'mood_picker.dart';
import 'providers.dart';

class CheckInEditorScreen extends ConsumerWidget {
  const CheckInEditorScreen({super.key, required this.date});

  final String date;

  static bool isValidDate(String date, String today) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
      DateTime.tryParse(date) != null &&
      date.compareTo(today) <= 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.tide;
    final today = ref.watch(todayKeyProvider);
    if (!isValidDate(date, today)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text("That day isn't available.", style: TideType.body(c.muted))),
      );
    }
    final repo = ref.read(checkInRepositoryProvider);
    final checkIn = ref.watch(checkInForDayProvider(date));
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, d MMM').format(DateTime.parse(date)),
            style: TideType.title(c.ink)),
      ),
      body: switch (checkIn) {
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              TideCard(
                title: 'Intention',
                child: AutosaveField(
                  initialValue: value?.intention,
                  hint: 'What would have made it good?',
                  onSave: (v) => repo.saveIntention(date, v),
                ),
              ),
              const SizedBox(height: 12),
              TideCard(
                title: 'Reflection',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MoodPicker(value: value?.mood, onChanged: (m) => repo.saveMood(date, m)),
                  const SizedBox(height: 12),
                  AutosaveField(
                    initialValue: value?.reflection,
                    hint: 'How was the day?',
                    minLines: 4,
                    maxLines: 10,
                    onSave: (v) => repo.saveReflection(date, v),
                  ),
                ]),
              ),
            ],
          ),
        _ when checkIn.hasError => Center(
            child: Text("Couldn't load this day.", style: TideType.body(c.muted)),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
