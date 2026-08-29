import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_schedule_policy.dart';
import 'package:catholic_daily/data/services/feast_reminder_preferences.dart';
import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:catholic_daily/data/services/notification_occurrence.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('journaled scheduler uses schema version 7', () {
    expect(FeastReminderService.scheduleSchemaVersion, 7);
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
    test('exposes exact occurrence arming outcomes to sync callers', () {
      final occurrence = NotificationOccurrence(
        occurrenceKey: 'feast:nigeria:2026-09-01:on_day:saint',
        localNotificationId: 123,
        scheduledFor: DateTime.utc(2026, 9, 1, 6),
        remoteExpiresAt: DateTime.utc(2026, 9, 1, 6, 2),
        localSafetyAt: DateTime.utc(2026, 9, 1, 6, 3),
        platform: 'ios',
        scheduleGeneration: 'feast-reminders-v5',
        timezone: 'Africa/Lagos',
        configurationFingerprint: 'config',
        localArmed: false,
        payload: '{"schema":3}',
      );
      final result = FeastReminderScheduleResult(
        eligibleCount: 1,
        scheduledCount: 0,
        failureCount: 0,
        scheduledThrough: DateTime(2026, 9, 1),
        usedExactDelivery: false,
        occurrences: [occurrence],
      );

      expect(result.occurrences.single.localArmed, isFalse);
    });

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

    test(
      'zero-success scheduling persists server-only rows and settings keeps enabled',
      () {
        final occurrence = NotificationOccurrence(
          occurrenceKey: 'feast:nigeria:2026-09-01:on_day:saint',
          localNotificationId: 123,
          scheduledFor: DateTime.utc(2026, 9, 1, 6),
          remoteExpiresAt: DateTime.utc(2026, 9, 1, 6, 2),
          localSafetyAt: DateTime.utc(2026, 9, 1, 6, 3),
          platform: 'android',
          scheduleGeneration: 'feast-reminders-v5',
          timezone: 'Africa/Lagos',
          configurationFingerprint: 'config',
          localArmed: false,
          payload: '{"schema":3}',
        );
        final result = FeastReminderScheduleResult(
          eligibleCount: 1,
          scheduledCount: 0,
          failureCount: 1,
          scheduledThrough: null,
          usedExactDelivery: false,
          occurrences: [occurrence],
        );

        expect(result.occurrencesToPersist, [occurrence]);
        expect(result.canKeepRemindersEnabled, isTrue);
        expect(result.canSyncServerOnlyOccurrences, isTrue);
        expect(result.needsLocalScheduleRepair, isTrue);
        expect(result.needsImmediateRepair, isTrue);
        expect(result.needsCriticalRemoteHandoff, isTrue);
      },
    );

    test('reports occurrence queue persistence independently', () {
      final result = FeastReminderScheduleResult(
        eligibleCount: 1,
        scheduledCount: 1,
        failureCount: 0,
        scheduledThrough: DateTime(2026, 9, 1),
        usedExactDelivery: true,
        occurrenceQueuePersisted: false,
      );

      expect(result.shouldPersistHorizon, isTrue);
      expect(result.occurrenceQueuePersisted, isFalse);
      expect(result.canKeepRemindersEnabled, isTrue);
      expect(result.needsImmediateRepair, isTrue);
      expect(result.needsCriticalRemoteHandoff, isTrue);
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

  test('UI call sites retain schedule results for immediate repair policy', () {
    for (final path in <String>[
      'lib/ui/screens/onboarding_screen.dart',
      'lib/ui/screens/feast_reminder_settings_sheet.dart',
      'lib/ui/screens/settings_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('FeastReminderScheduleResult? scheduleResult'));
      expect(source, contains('scheduleResult?.needsImmediateRepair'));
      expect(source, contains('needsCriticalRemoteHandoff'));
    }

    final settingsSource = File(
      'lib/ui/screens/feast_reminder_settings_sheet.dart',
    ).readAsStringSync();
    final enabledSchedulePath = settingsSource.substring(
      settingsSource.indexOf('scheduleResult = await service.scheduleForYear'),
      settingsSource.indexOf('NotificationScheduleSyncCoordinator('),
    );
    expect(enabledSchedulePath, isNot(contains('setEnabled(false)')));
    expect(enabledSchedulePath, isNot(contains('throw StateError')));
  });

  test('failure reconciliation retains only complete dates before failure', () {
    final items = <({DateTime date, String id})>[
      (date: DateTime(2026, 9, 1), id: 'a-1'),
      (date: DateTime(2026, 9, 2), id: 'b-1'),
      (date: DateTime(2026, 9, 1), id: 'a-2'),
    ];

    final result = FeastReminderScheduleReconciliation.retainBeforeFailure(
      items,
      failedDate: DateTime(2026, 9, 2),
      celebrationDate: (item) => item.date,
    );

    expect(result, hasLength(2));
    expect(result.map((item) => item.id), ['a-1', 'a-2']);
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
      'feast_reminder_scheduled_notification_payloads': <String>[
        'old-scheduled-payload',
      ],
      'feast_reminder_schedule_journal_payloads': <String>[
        'old-journal-payload',
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
    expect(preferences.scheduledNotificationPayloads, isEmpty);
    expect(preferences.scheduledConfigurationFingerprint, isNull);
    final raw = await SharedPreferences.getInstance();
    expect(raw.containsKey('feast_reminder_schedule_in_progress'), isFalse);
    expect(
      raw.containsKey('feast_reminder_schedule_journal_references'),
      isFalse,
    );
    expect(
      raw.containsKey('feast_reminder_scheduled_notification_payloads'),
      isFalse,
    );
    expect(
      raw.containsKey('feast_reminder_schedule_journal_payloads'),
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
        'feast_reminder_scheduled_notification_payloads': <String>[
          _v3Payload(DateTime.parse('2027-06-04T09:00:00+01:00')),
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
      expect(
        preferences.scheduleJournalPayloads
            .map(FeastReminderPayload.tryParse)
            .single
            ?.scheduledFor,
        DateTime.parse('2027-06-04T09:00:00+01:00'),
      );

      final replacement = <String>[
        '456|feast:general-roman:2027-06-05:on_day:new',
      ];
      final replacementPayloads = <String>[
        _v3Payload(DateTime.parse('2027-06-05T09:00:00+01:00')),
      ];
      await preferences.setScheduleJournalReferences(replacement);
      await preferences.setScheduleJournalPayloads(replacementPayloads);
      await preferences.completeScheduleUpdate(
        lastScheduledYear: 2027,
        scheduledThrough: DateTime(2027, 6, 5),
        schemaVersion: 6,
        scheduleGeneration: 'feast-reminders-v5',
        scheduleTimezone: 'Africa/Lagos',
        auditedAt: DateTime(2026, 8, 28),
        configurationFingerprint: 'v1|nigeria|feasts|9|0|false',
        references: replacement,
        payloads: replacementPayloads,
      );

      expect(preferences.scheduleInProgress, isFalse);
      expect(preferences.scheduleJournalReferences, isEmpty);
      expect(preferences.scheduleJournalPayloads, isEmpty);
      expect(preferences.scheduledNotificationReferences, replacement);
      final persistedPayload = FeastReminderPayload.tryParse(
        preferences.scheduledNotificationPayloads.single,
      );
      expect(
        persistedPayload?.scheduledFor,
        DateTime.parse('2027-06-05T09:00:00+01:00'),
      );
      expect(
        persistedPayload?.remoteExpiresAt,
        DateTime.parse('2027-06-05T09:02:00+01:00'),
      );
      expect(
        persistedPayload?.localSafetyAt,
        DateTime.parse('2027-06-05T09:03:00+01:00'),
      );
      expect(preferences.scheduleSchemaVersion, 6);
      expect(
        preferences.scheduledConfigurationFingerprint,
        'v1|nigeria|feasts|9|0|false',
      );
    },
  );

  test('an interrupted restart preserves its live schedule journal', () async {
    final journalReference = '456|feast:general-roman:2027-06-05:on_day:new';
    final journalPayload = _v3Payload(
      DateTime.parse('2027-06-05T09:00:00+01:00'),
    );
    SharedPreferences.setMockInitialValues({
      'feast_reminder_schedule_in_progress': true,
      'feast_reminder_schedule_journal_references': <String>[journalReference],
      'feast_reminder_schedule_journal_payloads': <String>[journalPayload],
    });
    FeastReminderPreferences.resetInstanceForTesting();
    final preferences = await FeastReminderPreferences.getInstance();

    await preferences.beginScheduleUpdate();

    expect(preferences.scheduleJournalReferences, contains(journalReference));
    expect(preferences.scheduleJournalPayloads, contains(journalPayload));
  });

  test('a failed invalidation clear retains recovery state', () async {
    SharedPreferences.setMockInitialValues({
      'feast_reminder_schedule_in_progress': true,
      'feast_reminder_schedule_schema_version': 7,
      'feast_reminder_schedule_journal_references': <String>['1|tag'],
    });
    FeastReminderPreferences.resetInstanceForTesting();
    final preferences = await FeastReminderPreferences.getInstance();
    FeastReminderPreferences.setWriteInterceptorForTesting((key, write) async {
      if (key == 'feast_reminder_schedule_schema_version') return false;
      return write();
    });
    addTearDown(FeastReminderPreferences.resetWriteInterceptorForTesting);

    expect(preferences.invalidateSchedule, throwsStateError);
    expect(preferences.scheduleInProgress, isTrue);
    expect(preferences.scheduleJournalReferences, isNotEmpty);
  });

  test('a failed completion write retains the in-progress journal', () async {
    final reference = '456|feast:general-roman:2027-06-05:on_day:new';
    final payload = _v3Payload(DateTime.parse('2027-06-05T09:00:00+01:00'));
    SharedPreferences.setMockInitialValues({
      'feast_reminder_schedule_in_progress': true,
      'feast_reminder_schedule_journal_references': <String>[reference],
      'feast_reminder_schedule_journal_payloads': <String>[payload],
    });
    FeastReminderPreferences.resetInstanceForTesting();
    final preferences = await FeastReminderPreferences.getInstance();
    FeastReminderPreferences.setWriteInterceptorForTesting((key, write) async {
      if (key == 'feast_reminder_scheduled_notification_references')
        return false;
      return write();
    });
    addTearDown(FeastReminderPreferences.resetWriteInterceptorForTesting);

    expect(
      () => preferences.completeScheduleUpdate(
        lastScheduledYear: 2027,
        scheduledThrough: DateTime(2027, 6, 5),
        schemaVersion: 7,
        scheduleGeneration: 'feast-reminders-v5',
        scheduleTimezone: 'Africa/Lagos',
        auditedAt: DateTime(2026, 8, 28),
        configurationFingerprint: 'v1|nigeria|feasts|9|0|false',
        references: [reference],
        payloads: [payload],
      ),
      throwsStateError,
    );
    expect(preferences.scheduleInProgress, isTrue);
    expect(preferences.scheduleJournalReferences, contains(reference));
    expect(preferences.scheduleJournalPayloads, contains(payload));
  });

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

String _v3Payload(DateTime scheduledFor) => FeastReminderPayload(
  celebrationDate: DateTime(
    scheduledFor.year,
    scheduledFor.month,
    scheduledFor.day,
  ),
  scheduledFor: scheduledFor,
  occurrenceKey:
      'feast:nigeria:${scheduledFor.year.toString().padLeft(4, '0')}-${scheduledFor.month.toString().padLeft(2, '0')}-${scheduledFor.day.toString().padLeft(2, '0')}:on_day:test',
  title: 'Test celebration',
  rank: 'Feast',
  saintProfileId: 'test',
  dayBefore: false,
).encode();
