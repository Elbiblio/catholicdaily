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
    final iosForced = FeastReminderRepairRequest.fromWorkmanager(
      FeastReminderBackgroundService.iosForcedRepairTaskIdentifier,
      null,
    );
    expect(iosForced.forceReschedule, isTrue);
    expect(
      iosForced.reason,
      FeastReminderRepairReason.exactAlarmCapabilityChanged,
    );
  });

  test('Android system broadcasts retain explicit forced repair reasons', () {
    for (final reason in <FeastReminderRepairReason>[
      FeastReminderRepairReason.timeSet,
      FeastReminderRepairReason.bootCompleted,
      FeastReminderRepairReason.packageReplaced,
      FeastReminderRepairReason.nativeOccurrenceStoreUnavailable,
    ]) {
      final request = FeastReminderRepairRequest.fromWorkmanager(
        FeastReminderBackgroundService.taskName,
        <String, dynamic>{
          FeastReminderRepairRequest.reasonInputKey: reason.name,
        },
      );

      expect(request.reason, reason);
      expect(request.forceReschedule, isTrue);
    }
  });

  test(
    'successful iOS background audit clears marker without resubmit',
    () async {
      final outbox = NotificationRepairOutbox();
      await outbox.markPending(reason: 'test');
      final repairs = <FeastReminderRepairRequest>[];
      final runner = NotificationBackgroundAuditRunner(
        audit: (_) async => true,
        enqueueRepair: (request) async => repairs.add(request),
        isIos: true,
        repairOutbox: outbox,
      );

      final succeeded = await runner.run(
        const FeastReminderRepairRequest(
          reason: FeastReminderRepairReason.occurrenceSync,
          forceReschedule: false,
        ),
      );

      expect(succeeded, isTrue);
      expect(repairs, isEmpty);
      expect(await outbox.hasPendingRepair, isFalse);
    },
  );

  test('failed iOS background audit resubmits the forced request', () async {
    final outbox = NotificationRepairOutbox();
    await outbox.markPending(reason: 'test');
    final repairs = <FeastReminderRepairRequest>[];
    final runner = NotificationBackgroundAuditRunner(
      audit: (_) async => false,
      enqueueRepair: (request) async => repairs.add(request),
      isIos: true,
      repairOutbox: outbox,
    );

    final succeeded = await runner.run(
      const FeastReminderRepairRequest(
        reason: FeastReminderRepairReason.timezoneChanged,
        forceReschedule: true,
      ),
    );

    expect(succeeded, isFalse);
    expect(repairs, hasLength(1));
    expect(repairs.single.reason, FeastReminderRepairReason.timezoneChanged);
    expect(repairs.single.forceReschedule, isTrue);
    expect(await outbox.hasPendingRepair, isTrue);
  });

  test('iOS resubmit failure keeps a durable pending marker', () async {
    final outbox = NotificationRepairOutbox();
    final runner = NotificationBackgroundAuditRunner(
      audit: (_) async => throw StateError('offline'),
      enqueueRepair: (_) async => throw StateError('registration failed'),
      isIos: true,
      repairOutbox: outbox,
    );

    final succeeded = await runner.run(
      const FeastReminderRepairRequest(
        reason: FeastReminderRepairReason.occurrenceSync,
        forceReschedule: false,
      ),
    );

    expect(succeeded, isFalse);
    expect(await outbox.hasPendingRepair, isTrue);
  });

  test('concurrent iOS failures coalesce BGProcessing registration', () async {
    final registration = Completer<void>();
    final registrationStarted = Completer<void>();
    var registrations = 0;
    final runner = NotificationBackgroundAuditRunner(
      audit: (_) async => false,
      enqueueRepair: (_) {
        registrations++;
        if (!registrationStarted.isCompleted) registrationStarted.complete();
        return registration.future;
      },
      isIos: true,
    );
    const request = FeastReminderRepairRequest(
      reason: FeastReminderRepairReason.occurrenceSync,
      forceReschedule: false,
    );

    final first = runner.run(request);
    final second = runner.run(request);
    await registrationStarted.future;

    expect(registrations, 1);
    registration.complete();
    expect(await Future.wait([first, second]), everyElement(isFalse));
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

  test(
    'startup initializes messaging while audit waits for executor',
    () async {
      final executor = Completer<void>();
      var auditStarted = false;
      var messagingStarted = false;
      final dispatcher = NotificationStartupSyncDispatcher(
        auditAndRepair: () async {
          auditStarted = true;
          return true;
        },
        initializeMessaging: () async => messagingStarted = true,
        enqueueRepair: () => executor.future,
      );

      final dispatch = dispatcher.dispatch();
      await Future<void>.delayed(Duration.zero);
      expect(auditStarted, isFalse);
      expect(messagingStarted, isTrue);

      executor.complete();
      await dispatch;
      expect(auditStarted, isTrue);
      expect(messagingStarted, isTrue);
    },
  );

  test(
    'startup keeps the outbox without detaching when executor fails',
    () async {
      var auditStarted = false;
      var messagingStarted = false;
      final dispatcher = NotificationStartupSyncDispatcher(
        auditAndRepair: () async {
          auditStarted = true;
          return true;
        },
        initializeMessaging: () async => messagingStarted = true,
        enqueueRepair: () async => throw UnsupportedError('no executor'),
      );

      await dispatcher.dispatch();
      await Future<void>.delayed(Duration.zero);

      expect(auditStarted, isFalse);
      expect(messagingStarted, isTrue);
      expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);
    },
  );

  test(
    'startup initializes messaging once when executor registration fails',
    () async {
      var auditRuns = 0;
      var messagingInitializations = 0;
      final dispatcher = NotificationStartupSyncDispatcher(
        auditAndRepair: () async {
          auditRuns++;
          return true;
        },
        initializeMessaging: () async => messagingInitializations++,
        enqueueRepair: () async => throw UnsupportedError('no executor'),
      );

      await Future.wait([dispatcher.dispatch(), dispatcher.dispatch()]);
      await Future<void>.delayed(Duration.zero);

      expect(auditRuns, 0);
      expect(messagingInitializations, 1);
    },
  );

  test('startup isolates messaging and executor registration errors', () async {
    final dispatcher = NotificationStartupSyncDispatcher(
      auditAndRepair: () async => true,
      initializeMessaging: () async => throw StateError('messaging failed'),
      enqueueRepair: () async => throw StateError('executor failed'),
    );

    await dispatcher.dispatch();
    await Future<void>.delayed(Duration.zero);

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
