import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';

class CheckIn {
  const CheckIn({required this.date, this.intention, this.mood, this.reflection});

  final String date;
  final String? intention;
  final int? mood;
  final String? reflection;

  bool get isEmpty => intention == null && mood == null && reflection == null;
}

class CheckInRepository {
  CheckInRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static String? _clean(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Stream<CheckIn?> watchDay(String date) =>
      (_db.select(_db.checkIns)..where((c) => c.date.equals(date) & c.deletedAt.isNull()))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toCheckIn(r));

  Future<void> saveIntention(String date, String text) =>
      _upsert(date, CheckInsCompanion(intention: Value(_clean(text))));

  Future<void> saveReflection(String date, String text) =>
      _upsert(date, CheckInsCompanion(reflection: Value(_clean(text))));

  Future<void> saveMood(String date, int? mood) {
    if (mood != null && (mood < 1 || mood > 5)) {
      throw ArgumentError.value(mood, 'mood', 'must be 1–5 or null');
    }
    return _upsert(date, CheckInsCompanion(mood: Value(mood)));
  }

  Expression<bool> _notEmpty($CheckInsTable c) =>
      c.deletedAt.isNull() &
      (c.intention.isNotNull() | c.mood.isNotNull() | c.reflection.isNotNull());

  Stream<List<CheckIn>> watchEntries() {
    final q = _db.select(_db.checkIns)
      ..where(_notEmpty)
      ..orderBy([(c) => OrderingTerm.desc(c.date)]);
    return q.watch().map((rows) => rows.map(_toCheckIn).toList());
  }

  Stream<Map<String, int?>> watchMonth(int year, int month) {
    final prefix = '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-';
    final q = _db.select(_db.checkIns)..where((c) => _notEmpty(c) & c.date.like('$prefix%'));
    return q.watch().map((rows) => {for (final r in rows) r.date: r.mood});
  }

  Future<Map<String, String>> reflectionsBetween(String from, String to) async {
    final rows = await (_db.select(_db.checkIns)
          ..where((c) =>
              c.deletedAt.isNull() &
              c.reflection.isNotNull() &
              c.date.isBiggerOrEqualValue(from) &
              c.date.isSmallerOrEqualValue(to)))
        .get();
    return {for (final r in rows) r.date: r.reflection!};
  }

  Future<void> _upsert(String date, CheckInsCompanion changes) => _db.transaction(() async {
        final now = _clock.now().toUtc();
        final existing = await (_db.select(_db.checkIns)..where((c) => c.date.equals(date)))
            .getSingleOrNull();
        if (existing == null) {
          await _db.into(_db.checkIns).insert(changes.copyWith(
                id: Value(_uuid.v4()),
                date: Value(date),
                createdAt: Value(now),
                updatedAt: Value(now),
              ));
        } else {
          await (_db.update(_db.checkIns)..where((c) => c.id.equals(existing.id)))
              .write(changes.copyWith(updatedAt: Value(now), deletedAt: const Value(null)));
        }
      });

  static CheckIn _toCheckIn(CheckInRow r) =>
      CheckIn(date: r.date, intention: r.intention, mood: r.mood, reflection: r.reflection);
}
