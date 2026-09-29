import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncListX<T> on AsyncValue<List<T>> {
  /// The loaded list, or empty while loading or on error.
  List<T> get listOrEmpty => switch (this) {
        AsyncData(:final value) => value,
        _ => <T>[],
      };
}
