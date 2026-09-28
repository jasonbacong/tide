import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/capture_repository.dart';

final inboxProvider = StreamProvider<List<Capture>>(
  (ref) => ref.watch(captureRepositoryProvider).watchInbox(),
);

final inboxCountProvider = StreamProvider<int>(
  (ref) => ref.watch(captureRepositoryProvider).watchInboxCount(),
);
