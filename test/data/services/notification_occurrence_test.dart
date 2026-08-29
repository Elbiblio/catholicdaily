import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
import 'package:catholic_daily/data/services/notification_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FeastReminderPayload payload(String saint, DateTime scheduledFor) {
    final celebrationDate = DateTime(2026, 9, saint == 'a' ? 1 : 2);
    final identity = FeastReminderNotificationContract.identity(
      region: 'nigeria',
      celebrationDate: celebrationDate,
      dayBefore: false,
      celebrationId: saint,
    );
    return FeastReminderPayload(
      celebrationDate: celebrationDate,
      scheduledFor: scheduledFor,
      remoteExpiresAt: FeastReminderNotificationContract.remoteExpiresAt(
        scheduledFor,
      ),
      localSafetyAt: FeastReminderNotificationContract.localSafetyAt(
        scheduledFor,
      ),
      occurrenceKey: identity.occurrenceKey,
      timeZone: 'Africa/Lagos',
      liturgicalRegion: 'nigeria',
      scheduleGeneration: 'feast-reminders-v5',
      title: 'Saint $saint',
      rank: 'Feast',
      saintProfileId: saint,
      dayBefore: false,
    );
  }

  test(
    'projects confirmed plugin schedules as armed with canonical timings',
    () {
      final first = payload('a', DateTime.utc(2026, 9, 1, 6));

      final rows = NotificationOccurrenceProjection.fromPayloads(
        [first],
        locallyArmedKeys: {first.occurrenceKey!},
        platform: 'android',
        configurationFingerprint: 'v1|nigeria|feasts|6|0|false',
      );

      expect(rows.single.localArmed, isTrue);
      expect(rows.single.localNotificationId, isNot(0));
      expect(rows.single.scheduledFor, first.scheduledFor);
      expect(
        rows.single.remoteExpiresAt.difference(rows.single.scheduledFor),
        const Duration(minutes: 2),
      );
      expect(
        rows.single.localSafetyAt.difference(rows.single.scheduledFor),
        const Duration(minutes: 3),
      );
      expect(rows.single.payload, contains('"schema":3'));
      expect(rows.single.status, NotificationOccurrenceStatus.scheduled);
      expect(rows.single.toApiJson()['status'], 'scheduled');
    },
  );

  test('derives lifecycle status from durable timestamps', () {
    final row = NotificationOccurrenceProjection.fromPayloads(
      [payload('a', DateTime.utc(2026, 9, 1, 6))],
      locallyArmedKeys: const {},
      platform: 'android',
      configurationFingerprint: 'config',
    ).single;

    expect(
      row.copyWith(receivedAt: DateTime.utc(2026, 9, 1, 6, 1)).status,
      NotificationOccurrenceStatus.received,
    );
    expect(
      row.copyWith(expiredAt: DateTime.utc(2026, 9, 1, 6, 2)).status,
      NotificationOccurrenceStatus.expired,
    );
    expect(
      row.copyWith(reconciledAt: DateTime.utc(2026, 9, 1, 6, 3)).status,
      NotificationOccurrenceStatus.reconciled,
    );
  });

  test(
    'keeps generated iOS overflow and unconfirmed schedules server-only',
    () {
      final first = payload('a', DateTime.utc(2026, 9, 1, 6));
      final overflow = payload('b', DateTime.utc(2026, 9, 2, 6));

      final rows = NotificationOccurrenceProjection.fromPayloads(
        [first, overflow],
        locallyArmedKeys: {first.occurrenceKey!},
        platform: 'ios',
        configurationFingerprint: 'v1|nigeria|feasts|6|0|false',
      );

      expect(rows, hasLength(2));
      expect(rows.first.localArmed, isTrue);
      expect(rows.last.localArmed, isFalse);
      expect(rows.last.platform, 'ios');
    },
  );

  test('rejects legacy payloads without exact occurrence timing', () {
    final legacy = FeastReminderPayload(
      celebrationDate: DateTime(2026, 9, 1),
      title: 'Legacy',
      rank: 'Feast',
      saintProfileId: null,
      dayBefore: false,
    );

    expect(
      NotificationOccurrenceProjection.fromPayloads(
        [legacy],
        locallyArmedKeys: const {},
        platform: 'android',
        configurationFingerprint: 'config',
      ),
      isEmpty,
    );
  });
}
