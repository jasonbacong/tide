import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncListX<T> on AsyncValue<List<T>> {
  /// The loaded list — or the previous one while reloading — else empty.
  /// Pair with [hasValue] before showing any "nothing here" copy.
  List<T> get listOrEmpty => value ?? <T>[];
}
