import 'package:catholic_daily/data/services/feast_reminder_schedule_policy.dart';
import 'package:catholic_daily/data/services/feast_reminder_preferences.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('journaled scheduler uses schema version 6', () {
    expect(FeastReminderService.scheduleSchemaVersion, 6);
  });

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
      'feast_reminder_schedule_generation': 'feast-reminders-v4',
      'feast_reminder_schedule_timezone': 'Africa/Lagos',
      'feast_reminder_last_audit_at': DateTime(
        2026,
        8,
        28,
      ).millisecondsSinceEpoch,
      'feast_reminder_scheduled_notification_references': <String>[
        '123|feast:general-roman:2027-06-04:on_day:test',
      ],
      'feast_reminder_schedule_in_progress': true,
      'feast_reminder_schedule_journal_references': <String>[
        '456|feast:general-roman:2027-06-05:on_day:pending',
      ],
      'feast_reminder_scheduled_configuration':
          'v1|generalRoman|feasts|9|0|false',
    });
    FeastReminderPreferences.resetInstanceForTesting();
    final preferences = await FeastReminderPreferences.getInstance();

    await preferences.invalidateSchedule();

    expect(preferences.lastScheduledYear, 0);
    expect(preferences.scheduleSchemaVersion, 0);
    expect(preferences.scheduledThrough, isNull);
    expect(preferences.scheduleGeneration, isNull);
    expect(preferences.scheduleTimezone, isNull);
    expect(preferences.lastAuditAt, isNull);
    expect(preferences.scheduledNotificationReferences, isEmpty);
    expect(preferences.scheduledConfigurationFingerprint, isNull);
    final raw = await SharedPreferences.getInstance();
    expect(raw.containsKey('feast_reminder_schedule_in_progress'), isFalse);
    expect(
      raw.containsKey('feast_reminder_schedule_journal_references'),
      isFalse,
    );
  });

  test(
    'schedule journal stays recoverable until completion marker is written',
    () async {
      SharedPreferences.setMockInitialValues({
        'feast_reminder_scheduled_notification_references': <String>[
          '123|feast:general-roman:2027-06-04:on_day:old',
        ],
      });
      FeastReminderPreferences.resetInstanceForTesting();
      final preferences = await FeastReminderPreferences.getInstance();

      await preferences.beginScheduleUpdate();

      expect(preferences.scheduleInProgress, isTrue);
      expect(
        preferences.cancellationNotificationReferences,
        contains('123|feast:general-roman:2027-06-04:on_day:old'),
      );

      final replacement = <String>[
        '456|feast:general-roman:2027-06-05:on_day:new',
      ];
      await preferences.setScheduleJournalReferences(replacement);
      await preferences.completeScheduleUpdate(
        lastScheduledYear: 2027,
        scheduledThrough: DateTime(2027, 6, 5),
        schemaVersion: 6,
        scheduleGeneration: 'feast-reminders-v5',
        scheduleTimezone: 'Africa/Lagos',
        auditedAt: DateTime(2026, 8, 28),
        configurationFingerprint: 'v1|nigeria|feasts|9|0|false',
        references: replacement,
      );

      expect(preferences.scheduleInProgress, isFalse);
      expect(preferences.scheduleJournalReferences, isEmpty);
      expect(preferences.scheduledNotificationReferences, replacement);
      expect(preferences.scheduleSchemaVersion, 6);
      expect(
        preferences.scheduledConfigurationFingerprint,
        'v1|nigeria|feasts|9|0|false',
      );
    },
  );

  test(
    'configuration fingerprint includes every scheduling preference',
    () async {
      SharedPreferences.setMockInitialValues({
        'feast_reminder_hour': 21,
        'feast_reminder_minute': 15,
        'feast_reminder_rank': 'all',
        'feast_reminder_day_before': true,
      });
      FeastReminderPreferences.resetInstanceForTesting();
      final preferences = await FeastReminderPreferences.getInstance();

      expect(
        preferences.configurationFingerprint(region: 'nigeria'),
        'v1|nigeria|all|21|15|true',
      );
    },
  );
}
