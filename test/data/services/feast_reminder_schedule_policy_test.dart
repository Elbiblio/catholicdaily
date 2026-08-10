import 'package:catholic_daily/data/services/feast_reminder_schedule_policy.dart';
import 'package:catholic_daily/data/services/feast_reminder_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FeastReminderSchedulePolicy', () {
    final policy = FeastReminderSchedulePolicy();
    final now = DateTime(2026, 8, 10, 12);

    test('reschedules when schema or usable horizon is missing', () {
      expect(
        policy.needsReschedule(
          now: now,
          scheduledThrough: now.add(const Duration(days: 90)),
          schemaMatches: false,
        ),
        isTrue,
      );
      expect(
        policy.needsReschedule(
          now: now,
          scheduledThrough: null,
          schemaMatches: true,
        ),
        isTrue,
      );
    });

    test('replenishes near horizon and preserves a healthy horizon', () {
      expect(
        policy.needsReschedule(
          now: now,
          scheduledThrough: now.add(const Duration(days: 10)),
          schemaMatches: true,
        ),
        isTrue,
      );
      expect(
        policy.needsReschedule(
          now: now,
          scheduledThrough: now.add(const Duration(days: 90)),
          schemaMatches: true,
        ),
        isFalse,
      );
    });

    test('uses inexact delivery when exact alarms are unavailable', () {
      expect(
        policy.androidMode(exactAllowed: true),
        AndroidScheduleMode.exactAllowWhileIdle,
      );
      expect(
        policy.androidMode(exactAllowed: false),
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });
  });

  group('FeastReminderScheduleResult', () {
    test('does not persist a horizon when every eligible schedule fails', () {
      final result = FeastReminderScheduleResult(
        eligibleCount: 3,
        scheduledCount: 0,
        failureCount: 3,
        scheduledThrough: null,
        usedExactDelivery: false,
      );

      expect(result.shouldPersistHorizon, isFalse);
    });

    test('preserves successful reminders across a partial failure', () {
      final through = DateTime(2026, 10, 1, 9);
      final result = FeastReminderScheduleResult(
        eligibleCount: 3,
        scheduledCount: 2,
        failureCount: 1,
        scheduledThrough: through,
        usedExactDelivery: true,
      );

      expect(result.shouldPersistHorizon, isTrue);
      expect(result.scheduledThrough, through);
    });

    test('persists an empty requested range through its requested end', () {
      final through = DateTime(2026, 10, 1);
      final result = FeastReminderScheduleResult(
        eligibleCount: 0,
        scheduledCount: 0,
        failureCount: 0,
        scheduledThrough: through,
        usedExactDelivery: false,
      );

      expect(result.shouldPersistHorizon, isTrue);
    });
  });

  test('invalidating a schedule clears every freshness marker', () async {
    SharedPreferences.setMockInitialValues({
      'feast_reminder_last_year': 2027,
      'feast_reminder_schedule_schema_version': 3,
      'feast_reminder_scheduled_through': DateTime(
        2027,
        6,
        4,
      ).millisecondsSinceEpoch,
    });
    final preferences = await FeastReminderPreferences.getInstance();

    await preferences.invalidateSchedule();

    expect(preferences.lastScheduledYear, 0);
    expect(preferences.scheduleSchemaVersion, 0);
    expect(preferences.scheduledThrough, isNull);
  });
}
