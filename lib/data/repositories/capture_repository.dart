import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../enums.dart';

class Capture {
  const Capture({required this.id, required this.body, required this.createdAt});

  final String id;
  final String body;
  final DateTime createdAt;
}

class CaptureRepository {
  CaptureRepository(this._db, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// Saves trimmed [raw] to the inbox. Returns null and saves nothing if it is blank.
  Future<Capture?> add(String raw) async {
    final body = raw.trim();
    if (body.isEmpty) return null;
    final now = _clock.now();
    final stamp = now.toUtc();
    final id = _uuid.v4();
    await _db.into(_db.captures).insert(CapturesCompanion.insert(
          id: id,
          createdAt: stamp,
          updatedAt: stamp,
          body: body,
          status: CaptureStatus.inbox,
        ));
    return Capture(id: id, body: body, createdAt: now);
  }

  Stream<List<Capture>> watchInbox() {
    final query = _db.select(_db.captures)
      ..where((c) => c.status.equalsValue(CaptureStatus.inbox) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.createdAt),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch().map((rows) => rows.map(_toCapture).toList());
  }

  Stream<int> watchInboxCount() => watchInbox().map((captures) => captures.length);

  Future<void> archive(String id) => _setStatus(id, CaptureStatus.archived);

  Future<void> unarchive(String id) => _setStatus(id, CaptureStatus.inbox);

  Future<void> _setStatus(String id, CaptureStatus status) =>
      (_db.update(_db.captures)..where((c) => c.id.equals(id))).write(
        CapturesCompanion(status: Value(status), updatedAt: Value(_clock.now().toUtc())),
      );

  static Capture _toCapture(CaptureRow row) =>
      Capture(id: row.id, body: row.body, createdAt: row.createdAt.toLocal());
}
