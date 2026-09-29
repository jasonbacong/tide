import '../../data/enums.dart';
import '../../data/repositories/task_repository.dart';

const taskMinuteOptions = [5, 15, 30, 60];

String energyLabel(Energy e) => switch (e) {
      Energy.low => 'Low',
      Energy.medium => 'Medium',
      Energy.high => 'High',
    };

String minutesLabel(int minutes) => minutes >= 60 ? '60+ min' : '$minutes min';

/// "Low energy · 15 min", or '' when the task has no tags.
String taskMeta(Task t) => [
      if (t.energy != null) '${energyLabel(t.energy!)} energy',
      if (t.minutes != null) minutesLabel(t.minutes!),
    ].join(' · ');
