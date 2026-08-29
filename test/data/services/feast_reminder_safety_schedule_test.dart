import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_schedule_policy.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeastReminderSafetySchedule', () {
    test('preserves the intended server time and delays the OS trigger', () {
      final intended = DateTime.parse('2026-08-29T07:00:00+01:00');
      final schedule = FeastReminderSafetySchedule.fromIntendedTime(intended);
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 8, 29),
        scheduledFor: schedule.scheduledFor,
        remoteExpiresAt: schedule.remoteExpiresAt,
        localSafetyAt: schedule.localSafetyAt,
        occurrenceKey: 'feast:nigeria:2026-08-29:on_day:test',
        title: 'Test celebration',
        rank: 'Feast',
        saintProfileId: 'test',
        dayBefore: false,
      );

      expect(schedule.scheduledFor, intended);
      expect(
        schedule.remoteExpiresAt,
        intended.add(const Duration(minutes: 2)),
      );
      expect(schedule.localSafetyAt, intended.add(const Duration(minutes: 3)));
      expect(
        FeastReminderSafetySchedule.localTriggerFor(payload),
        payload.localSafetyAt,
      );
    });

    test('rejects a payload without a safety trigger', () {
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 8, 29),
        scheduledFor: DateTime.parse('2026-08-29T07:00:00+01:00'),
        occurrenceKey: 'feast:nigeria:2026-08-29:on_day:test',
        title: 'Test celebration',
        rank: 'Feast',
        saintProfileId: 'test',
        dayBefore: false,
      );

      expect(
        () => FeastReminderSafetySchedule.localTriggerFor(payload),
        throwsArgumentError,
      );
    });

    test('retains a safety copy during its three-minute grace window', () {
      final intended = DateTime.parse('2026-08-29T07:00:00+01:00');

      expect(
        FeastReminderSafetySchedule.isLocallySchedulable(
          scheduledFor: intended,
          now: intended.add(const Duration(minutes: 1)),
        ),
        isTrue,
      );
      expect(
        FeastReminderSafetySchedule.isLocallySchedulable(
          scheduledFor: intended,
          now: intended.add(const Duration(minutes: 3)),
        ),
        isFalse,
      );
    });
  });

  group('FeastReminderService pending occurrence matching', () {
    const occurrenceKey = 'feast:nigeria:2026-08-29:on_day:test';

    test('requires both the stable ID and canonical payload key', () {
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 8, 29),
        scheduledFor: DateTime.parse('2026-08-29T07:00:00+01:00'),
        occurrenceKey: occurrenceKey,
        title: 'Test celebration',
        rank: 'Feast',
        saintProfileId: 'test',
        dayBefore: false,
      );
      final request = PendingNotificationRequest(
        FeastReminderNotificationContract.stableNotificationId(occurrenceKey),
        'Test celebration',
        'Test body',
        payload.encode(),
      );

      expect(
        FeastReminderService.pendingRequestMatchesOccurrenceForTesting(
          request,
          occurrenceKey,
        ),
        isTrue,
      );
      expect(
        FeastReminderService.pendingRequestMatchesOccurrenceForTesting(
          request,
          '$occurrenceKey-other',
        ),
        isFalse,
      );
    });

    test('does not claim an occurrence is absent without its payload', () {
      final request = PendingNotificationRequest(
        FeastReminderNotificationContract.stableNotificationId(occurrenceKey),
        'Test celebration',
        'Test body',
        null,
      );

      expect(
        FeastReminderService.pendingOccurrenceStatusForTesting([
          request,
        ], occurrenceKey),
        isNull,
      );
    });

    test('does not claim an occurrence is absent for a legacy payload', () {
      final request = PendingNotificationRequest(
        FeastReminderNotificationContract.stableNotificationId(occurrenceKey),
        'Test celebration',
        'Test body',
        'feast:2026-08-29T00:00:00.000:day',
      );

      expect(
        FeastReminderService.pendingOccurrenceStatusForTesting([
          request,
        ], occurrenceKey),
        isNull,
      );
    });

    test('does not claim an occurrence is absent for a malformed payload', () {
      final request = PendingNotificationRequest(
        FeastReminderNotificationContract.stableNotificationId(occurrenceKey),
        'Test celebration',
        'Test body',
        '{not JSON',
      );

      expect(
        FeastReminderService.pendingOccurrenceStatusForTesting([
          request,
        ], occurrenceKey),
        isNull,
      );
    });
  });

  test('schedule repair excludes remotely presented occurrences', () {
    const claimedKey = 'feast:nigeria:2026-08-15:on_day:assumption';

    expect(
      FeastReminderService.shouldScheduleLocalOccurrenceForTesting(
        claimedKey,
        const <String>{claimedKey},
      ),
      isFalse,
    );
    expect(
      FeastReminderService.shouldScheduleLocalOccurrenceForTesting(
        'feast:nigeria:2026-08-16:on_day:saint',
        const <String>{claimedKey},
      ),
      isTrue,
    );
  });
}
