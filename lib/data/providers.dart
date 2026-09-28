import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/day_period.dart';
import 'clock.dart';
import 'db/app_database.dart';
import 'repositories/capture_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => CaptureRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// Current time, re-read every minute and on app resume (see TideApp).
class NowNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => state = clock.now());
    ref.onDispose(timer.cancel);
    return clock.now();
  }

  void refresh() => state = ref.read(clockProvider).now();
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

final dayPeriodProvider = Provider<PartOfDay>((ref) => periodFor(ref.watch(nowProvider)));
