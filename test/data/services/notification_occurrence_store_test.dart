import 'package:catholic_daily/data/services/notification_occurrence.dart';
import 'package:catholic_daily/data/services/notification_occurrence_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  NotificationOccurrence occurrence({
    String key = 'feast:nigeria:2026-09-01:on_day:saint',
    bool localArmed = true,
    DateTime? remoteExpiresAt,
    DateTime? reconciledAt,
  }) => NotificationOccurrence(
    occurrenceKey: key,
    localNotificationId: 12345,
    scheduledFor: DateTime.utc(2026, 9, 1, 6),
    remoteExpiresAt: remoteExpiresAt ?? DateTime.utc(2026, 9, 1, 6, 2),
    localSafetyAt: DateTime.utc(2026, 9, 1, 6, 3),
    platform: 'android',
    scheduleGeneration: 'feast-reminders-v5',
    timezone: 'Africa/Lagos',
    configurationFingerprint: 'v1|nigeria|feasts|6|0|false',
    localArmed: localArmed,
    payload: '{"schema":3}',
    reconciledAt: reconciledAt,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationOccurrenceStore.resetWriteInterceptorForTesting();
  });

  tearDown(NotificationOccurrenceStore.resetWriteInterceptorForTesting);

  test('persists pending occurrence state across store instances', () async {
    await NotificationOccurrenceStore().upsertAll([occurrence()]);

    final reloaded = await NotificationOccurrenceStore().pendingOccurrences();

    expect(reloaded, hasLength(1));
    expect(reloaded.single.occurrenceKey, occurrence().occurrenceKey);
    expect(reloaded.single.payload, '{"schema":3}');
  });

  test(
    'merges by key and leaves an identical synchronized row clean',
    () async {
      final store = NotificationOccurrenceStore();
      await store.upsertAll([occurrence()]);
      await store.markSynchronized(
        occurrences: [occurrence()],
        eventIds: const [],
        synchronizedAt: DateTime.utc(2026, 8, 28),
      );

      await store.upsertAll([occurrence()]);
      expect(await store.pendingOccurrences(), isEmpty);

      await store.upsertAll([occurrence(localArmed: false)]);
      final pending = await store.pendingOccurrences();
      expect(pending, hasLength(1));
      expect(pending.single.localArmed, isFalse);
    },
  );

  test('records reconciliation events durably and idempotently', () async {
    final store = NotificationOccurrenceStore();
    await store.upsertAll([occurrence()]);
    final event = NotificationOccurrenceEvent(
      occurrenceKey: occurrence().occurrenceKey,
      type: NotificationOccurrenceEventType.received,
      occurredAt: DateTime.utc(2026, 9, 1, 6, 1),
    );

    await store.recordEvent(event);
    await store.recordEvent(event);

    final events = await NotificationOccurrenceStore().pendingEvents();
    final rows = await store.allOccurrences();
    expect(events, hasLength(1));
    expect(rows.single.receivedAt, event.occurredAt);
    expect(rows.single.needsSync, isTrue);
  });

  test('does not acknowledge a newer mutation that was not sent', () async {
    final store = NotificationOccurrenceStore();
    final sent = occurrence(localArmed: true);
    await store.upsertAll([sent]);
    await store.upsertAll([occurrence(localArmed: false)]);

    await store.markSynchronized(
      occurrences: [sent],
      eventIds: const [],
      synchronizedAt: DateTime.utc(2026, 8, 29),
    );

    final pending = await store.pendingOccurrences();
    expect(pending, hasLength(1));
    expect(pending.single.localArmed, isFalse);
  });

  test(
    'schedule replacement reconciles rows omitted by the new generation',
    () async {
      final store = NotificationOccurrenceStore();
      final old = occurrence(key: 'old');
      await store.upsertAll([old]);
      await store.markSynchronized(
        occurrences: [old],
        eventIds: const [],
        synchronizedAt: DateTime.utc(2026, 8, 28),
      );
      final replacement = occurrence(key: 'new', localArmed: false);
      final reconciledAt = DateTime.utc(2026, 8, 29);

      await store.replaceSchedule([replacement], reconciledAt: reconciledAt);

      final rows = await store.pendingOccurrences();
      expect(rows.map((row) => row.occurrenceKey), containsAll(['old', 'new']));
      final reconciled = rows.singleWhere((row) => row.occurrenceKey == 'old');
      expect(reconciled.localArmed, isFalse);
      expect(reconciled.reconciledAt, reconciledAt);
      expect(
        (await store.pendingEvents()).single.type,
        NotificationOccurrenceEventType.reconciled,
      );
    },
  );

  test(
    'schedule replacement safely reactivates a reconciled future key',
    () async {
      final store = NotificationOccurrenceStore();
      final row = occurrence();
      await store.upsertAll([row]);
      await store.replaceSchedule(
        const [],
        reconciledAt: DateTime.utc(2026, 8, 29),
      );

      await store.replaceSchedule([
        row,
      ], reconciledAt: DateTime.utc(2026, 8, 29, 1));

      final active = (await store.allOccurrences()).single;
      expect(active.localArmed, isTrue);
      expect(active.reconciledAt, isNull);
      expect(await store.pendingEvents(), isEmpty);
    },
  );

  test('expiry reconciliation de-arms exactly once', () async {
    final store = NotificationOccurrenceStore();
    await store.upsertAll([occurrence()]);
    final now = DateTime.utc(2026, 9, 1, 6, 4);

    await Future.wait([
      store.reconcileExpired(now: now),
      store.reconcileExpired(now: now.add(const Duration(seconds: 1))),
    ]);

    final row = (await store.allOccurrences()).single;
    expect(row.localArmed, isFalse);
    expect(row.expiredAt, isNotNull);
    expect(row.reconciledAt, isNotNull);
    expect(
      (await store.pendingEvents()).where(
        (event) => event.type == NotificationOccurrenceEventType.reconciled,
      ),
      hasLength(1),
    );
  });

  test('pending-alarm audit reconciles a missing armed occurrence', () async {
    final store = NotificationOccurrenceStore();
    await store.upsertAll([occurrence()]);

    await store.reconcileLocalArming(
      pendingOccurrenceKeys: const {},
      reconciledAt: DateTime.utc(2026, 8, 29),
    );

    final row = (await store.allOccurrences()).single;
    expect(row.localArmed, isFalse);
    expect(row.reconciledAt, DateTime.utc(2026, 8, 29));
  });

  test('prunes only reconciled rows after the retention window', () async {
    final store = NotificationOccurrenceStore();
    final oldExpiry = DateTime.utc(2026, 7, 1);
    await store.upsertAll([
      occurrence(
        key: 'old-reconciled',
        remoteExpiresAt: oldExpiry,
        reconciledAt: oldExpiry,
      ),
      occurrence(key: 'old-unreconciled', remoteExpiresAt: oldExpiry),
      occurrence(
        key: 'recent-reconciled',
        remoteExpiresAt: DateTime.utc(2026, 8, 27),
        reconciledAt: DateTime.utc(2026, 8, 27),
      ),
    ]);

    await store.prune(
      now: DateTime.utc(2026, 8, 28),
      retention: const Duration(days: 7),
    );

    expect(
      (await store.allOccurrences()).map((row) => row.occurrenceKey),
      containsAll(<String>['old-unreconciled', 'recent-reconciled']),
    );
    expect(
      (await store.allOccurrences()).map((row) => row.occurrenceKey),
      isNot(contains('old-reconciled')),
    );
  });

  test('throws when SharedPreferences rejects the checked write', () async {
    NotificationOccurrenceStore.setWriteInterceptorForTesting(
      (_, __) async => false,
    );

    expect(
      NotificationOccurrenceStore().upsertAll([occurrence()]),
      throwsA(isA<StateError>()),
    );
    expect(await NotificationOccurrenceStore().allOccurrences(), isEmpty);
  });
}
