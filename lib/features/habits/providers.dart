import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/habit_repository.dart';

final todayHabitsProvider = StreamProvider<List<HabitToday>>((ref) =>
    ref.watch(habitRepositoryProvider).watchDay(ref.watch(todayKeyProvider)));
