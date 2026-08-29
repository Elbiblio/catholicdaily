import 'dart:async';

import 'package:catholic_daily/data/services/feast_reminder_background_service.dart';
import 'package:catholic_daily/data/services/notification_occurrence_sync_service.dart';
import 'package:catholic_daily/data/services/notification_repair_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  const policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: 6,
    expectedScheduleGeneration: 'feast-reminders-v5',
    minimumCoverage: Duration(days: 30),
  );
  final now = DateTime(2026, 8, 28, 12);

  FeastReminderAuditSnapshot healthy() => FeastReminderAuditSnapshot(
    enabled: true,
    permissionGranted: true,
    schemaVersion: 6,
    scheduleGeneration: 'feast-reminders-v5',
    scheduledTimezone: 'Africa/Lagos',
    currentTimezone: 'Africa/Lagos',
    scheduledThrough: DateTime(2026, 10, 1),
    scheduleInProgress: false,
    hasCancellationState: false,
    scheduledConfigurationFingerprint: 'v1|nigeria|feasts|9|0|false',
    currentConfigurationFingerprint: 'v1|nigeria|feasts|9|0|false',
  );

  test('skips disabled and permission-denied installations successfully', () {
    expect(
      policy.decide(healthy().copyWith(enabled: false), now: now),
      FeastReminderAuditDecision.skip,
    );
    expect(
      policy.decide(healthy().copyWith(permissionGranted: false), now: now),
      FeastReminderAuditDecision.skip,
    );
  });

  test('cleans interrupted or cancellable schedules before disabled skip', () {
    expect(
      policy.decide(
        healthy().copyWith(enabled: false, scheduleInProgress: true),
        now: now,
      ),
      FeastReminderAuditDecision.cleanup,
    );
    expect(
      policy.decide(
        healthy().copyWith(
          permissionGranted: false,
          hasCancellationState: true,
        ),
        now: now,
      ),
      FeastReminderAuditDecision.cleanup,
    );
  });

  test('repairs schema, generation, timezone, and short coverage drift', () {
    expect(
      policy.decide(healthy().copyWith(schemaVersion: 4), now: now),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(scheduleGeneration: 'feast-reminders-v4'),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(currentTimezone: 'Europe/London'),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
    expect(
      policy.decide(
        healthy().copyWith(scheduledThrough: DateTime(2026, 9, 20)),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
  });

  test('keeps a current schedule untouched', () {
    expect(
      policy.decide(healthy(), now: now),
      FeastReminderAuditDecision.current,
    );
  });

  test('forced exact-alarm repair overrides a healthy schedule', () {
    expect(
      policy.decide(healthy(), now: now, forceReschedule: true),
      FeastReminderAuditDecision.repair,
    );
  });

  test('dispatcher input carries exact-alarm and timezone repair reasons', () {
    final exactAlarm = FeastReminderRepairRequest.fromWorkmanager(
      FeastReminderBackgroundService.taskName,
      const FeastReminderRepairRequest(
        reason: FeastReminderRepairReason.exactAlarmCapabilityChanged,
        forceReschedule: true,
      ).toInputData(),
    );
    final timezone = FeastReminderRepairRequest.fromWorkmanager(
      FeastReminderBackgroundService.taskName,
      const FeastReminderRepairRequest(
        reason: FeastReminderRepairReason.timezoneChanged,
        forceReschedule: true,
      ).toInputData(),
    );

    expect(exactAlarm.forceReschedule, isTrue);
    expect(
      exactAlarm.reason,
      FeastReminderRepairReason.exactAlarmCapabilityChanged,
    );
    expect(timezone.forceReschedule, isTrue);
    expect(timezone.reason, FeastReminderRepairReason.timezoneChanged);
  });

  test('startup durable handoff does not gate runApp on remote sync', () async {
    final audit = Completer<bool>();
    final messaging = Completer<void>();
    var auditStarted = false;
    var messagingStarted = false;
    final dispatcher = NotificationStartupSyncDispatcher(
      auditAndRepair: () {
        auditStarted = true;
        return audit.future;
      },
      initializeMessaging: () {
        messagingStarted = true;
        return messaging.future;
      },
      enqueueRepair: () async {},
    );

    await dispatcher.dispatch();

    expect(auditStarted, isTrue);
    expect(messagingStarted, isTrue);
    expect(audit.isCompleted, isFalse);
    expect(messaging.isCompleted, isFalse);
    expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);
  });

  test('startup detached audit errors still enqueue repair', () async {
    var repairs = 0;
    final dispatcher = NotificationStartupSyncDispatcher(
      auditAndRepair: () async => throw StateError('offline'),
      initializeMessaging: () async {},
      enqueueRepair: () async => repairs++,
    );

    await dispatcher.dispatch();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repairs, 1);
  });

  test('startup coalesces simultaneous audit and messaging repair', () async {
    var repairs = 0;
    final dispatcher = NotificationStartupSyncDispatcher(
      auditAndRepair: () async => false,
      initializeMessaging: () async => throw StateError('offline'),
      enqueueRepair: () async => repairs++,
    );

    await dispatcher.dispatch();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repairs, 1);
  });

  test(
    'background retry decisions include durable occurrence reconciliation',
    () {
      const syncPolicy = NotificationBackgroundSyncPolicy();

      expect(
        syncPolicy.succeeded(
          installationSynchronized: true,
          occurrenceResult: NotificationOccurrenceSyncResult.success,
        ),
        isTrue,
      );
      expect(
        syncPolicy.succeeded(
          installationSynchronized: true,
          occurrenceResult: NotificationOccurrenceSyncResult.invalid,
        ),
        isTrue,
      );
      expect(
        syncPolicy.succeeded(
          installationSynchronized: true,
          occurrenceResult: NotificationOccurrenceSyncResult.retry,
        ),
        isFalse,
      );
      expect(
        syncPolicy.succeeded(
          installationSynchronized: true,
          occurrenceResult: NotificationOccurrenceSyncResult.reRegister,
        ),
        isFalse,
      );
      expect(
        syncPolicy.succeeded(
          installationSynchronized: false,
          occurrenceResult: NotificationOccurrenceSyncResult.success,
        ),
        isFalse,
      );
    },
  );

  test(
    'repairs an interrupted schedule even when freshness markers look current',
    () {
      expect(
        policy.decide(healthy().copyWith(scheduleInProgress: true), now: now),
        FeastReminderAuditDecision.repair,
      );
    },
  );

  test('repairs when settings differ from the scheduled configuration', () {
    expect(
      policy.decide(
        healthy().copyWith(
          currentConfigurationFingerprint: 'v1|nigeria|all|21|15|true',
        ),
        now: now,
      ),
      FeastReminderAuditDecision.repair,
    );
  });
}
