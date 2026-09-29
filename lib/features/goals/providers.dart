import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/habit_repository.dart';
import '../../data/repositories/task_repository.dart';

final activeGoalsProvider = StreamProvider<List<GoalWithProgress>>(
    (ref) => ref.watch(goalRepositoryProvider).watchActive());

final pastGoalsProvider = StreamProvider<List<GoalWithProgress>>(
    (ref) => ref.watch(goalRepositoryProvider).watchPast());

final goalProvider = StreamProvider.autoDispose
    .family<Goal?, String>((ref, id) => ref.watch(goalRepositoryProvider).watchGoal(id));

final milestonesProvider = StreamProvider.autoDispose.family<List<Milestone>, String>(
    (ref, id) => ref.watch(goalRepositoryProvider).watchMilestones(id));

final linkedHabitsProvider = StreamProvider.autoDispose.family<List<Habit>, String>(
    (ref, id) => ref.watch(habitRepositoryProvider).watchForGoal(id));

final linkedTasksProvider = StreamProvider.autoDispose.family<List<Task>, String>(
    (ref, id) => ref.watch(taskRepositoryProvider).watchOpenForGoal(id));

final goalTitlesProvider = StreamProvider<Map<String, String>>(
    (ref) => ref.watch(goalRepositoryProvider).watchTitles());
