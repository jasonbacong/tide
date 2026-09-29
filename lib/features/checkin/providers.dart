import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/check_in_repository.dart';

final checkInForDayProvider = StreamProvider.autoDispose.family<CheckIn?, String>(
  (ref, date) => ref.watch(checkInRepositoryProvider).watchDay(date),
);

final journalEntriesProvider = StreamProvider<List<CheckIn>>(
  (ref) => ref.watch(checkInRepositoryProvider).watchEntries(),
);

/// Key: (year, month).
final monthMoodsProvider = StreamProvider.autoDispose.family<Map<String, int?>, (int, int)>(
  (ref, ym) => ref.watch(checkInRepositoryProvider).watchMonth(ym.$1, ym.$2),
);
