import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/task_repository.dart';

final todayOpenTasksProvider = StreamProvider<List<Task>>((ref) =>
    ref.watch(taskRepositoryProvider).watchTodayOpen(ref.watch(todayKeyProvider)));

final todayDoneTasksProvider = StreamProvider<List<Task>>((ref) =>
    ref.watch(taskRepositoryProvider).watchDoneOn(ref.watch(todayKeyProvider)));

final laterTasksProvider =
    StreamProvider<List<Task>>((ref) => ref.watch(taskRepositoryProvider).watchLater());
