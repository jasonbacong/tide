import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/data/db/app_database.dart';
import 'package:tide/data/repositories/capture_repository.dart';

import '../support/fake_clock.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late CaptureRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime(2026, 9, 28, 9));
    repo = CaptureRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<List<String>> inboxBodies() async =>
      (await repo.watchInbox().first).map((c) => c.body).toList();

  test('add trims the text and puts it in the inbox', () async {
    final capture = await repo.add('  Call mum  ');
    expect(capture!.body, 'Call mum');
    expect(capture.createdAt, clock.now());
    expect(await inboxBodies(), ['Call mum']);
  });

  test('blank text saves nothing', () async {
    expect(await repo.add(''), isNull);
    expect(await repo.add('   \n  '), isNull);
    expect(await inboxBodies(), isEmpty);
  });

  test('inbox lists oldest first', () async {
    await repo.add('first');
    clock.advance(const Duration(minutes: 1));
    await repo.add('second');
    expect(await inboxBodies(), ['first', 'second']);
  });

  test('archive hides a capture and unarchive brings it back', () async {
    final c = await repo.add('Water the plants');
    await repo.archive(c!.id);
    expect(await inboxBodies(), isEmpty);
    await repo.unarchive(c.id);
    expect(await inboxBodies(), ['Water the plants']);
  });

  test('long, emoji and non-Latin text round-trips exactly', () async {
    final text = ('Plan 🌊 trip — café, 東京, مرحبا. ' * 170).trim();
    expect(text.length, greaterThan(5000));
    await repo.add(text);
    expect(await inboxBodies(), [text]);
  });

  test('inbox count follows the inbox', () async {
    await repo.add('one');
    await repo.add('two');
    expect(await repo.watchInboxCount().first, 2);
  });

  test('timestamps are stored in UTC and read back as the same local moment', () async {
    final local = DateTime(2026, 9, 28, 9, 30);
    clock.set(local);
    final c = await repo.add('Stored in UTC');
    final raw = await db
        .customSelect('SELECT created_at, updated_at FROM captures WHERE id = ?',
            variables: [Variable.withString(c!.id)])
        .getSingle();
    expect(raw.read<String>('created_at'), endsWith('Z'));
    expect(raw.read<String>('updated_at'), endsWith('Z'));

    final read = (await repo.watchInbox().first).single;
    expect(read.createdAt.isUtc, isFalse);
    expect(read.createdAt.isAtSameMomentAs(local), isTrue);
  });

  test('inbox order follows real time even when the clock offset changes', () async {
    clock.set(DateTime(2026, 9, 28, 10, 0)); // local, e.g. +02:00
    await repo.add('earlier');
    clock.set(DateTime(2026, 9, 28, 10, 1).toUtc()); // one minute later, expressed in UTC
    await repo.add('later');
    expect(await inboxBodies(), ['earlier', 'later']);
  });

  test('markConverted removes a capture from the inbox', () async {
    final c = await repo.add('Book a table');
    await repo.markConverted(c!.id);
    expect(await inboxBodies(), isEmpty);
  });
}
