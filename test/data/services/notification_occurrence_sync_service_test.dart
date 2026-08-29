import 'dart:async';

import 'package:catholic_daily/data/services/notification_installation.dart';
import 'package:catholic_daily/data/services/notification_installation_store.dart';
import 'package:catholic_daily/data/services/notification_occurrence.dart';
import 'package:catholic_daily/data/services/notification_occurrence_api.dart';
import 'package:catholic_daily/data/services/notification_occurrence_store.dart';
import 'package:catholic_daily/data/services/notification_occurrence_sync_service.dart';
import 'package:catholic_daily/data/services/notification_repair_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  NotificationOccurrence occurrence() => NotificationOccurrence(
    occurrenceKey: 'feast:nigeria:2026-09-01:on_day:saint',
    localNotificationId: 12345,
    scheduledFor: DateTime.utc(2026, 9, 1, 6),
    remoteExpiresAt: DateTime.utc(2026, 9, 1, 6, 2),
    localSafetyAt: DateTime.utc(2026, 9, 1, 6, 3),
    platform: 'android',
    scheduleGeneration: 'feast-reminders-v5',
    timezone: 'Africa/Lagos',
    configurationFingerprint: 'v1|nigeria|feasts|6|0|false',
    localArmed: true,
    payload: '{"schema":3}',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationOccurrenceStore.resetWriteInterceptorForTesting();
    NotificationRepairOutbox.resetWriteInterceptorForTesting();
  });

  test(
    'success marks the exact pending rows and events synchronized',
    () async {
      final store = NotificationOccurrenceStore();
      final row = occurrence();
      final event = NotificationOccurrenceEvent(
        occurrenceKey: row.occurrenceKey,
        type: NotificationOccurrenceEventType.received,
        occurredAt: DateTime.utc(2026, 9, 1, 6, 1),
      );
      await store.upsertAll([row]);
      await store.recordEvent(event);
      final api = _FakeApi(NotificationOccurrenceApiResult.success);
      final service = NotificationOccurrenceSyncService(
        api: api,
        store: store,
        installationStore: _FakeInstallationStore(),
      );

      final result = await service.syncPending(
        synchronizedAt: DateTime.utc(2026, 8, 29),
      );

      expect(result, NotificationOccurrenceSyncResult.success);
      expect(api.occurrences.single.occurrenceKey, row.occurrenceKey);
      expect(api.events.single.id, event.id);
      expect(await store.pendingOccurrences(), isEmpty);
      expect(await store.pendingEvents(), isEmpty);
    },
  );

  test(
    'installation loss preserves pending data and requests re-registration',
    () async {
      final store = NotificationOccurrenceStore();
      await store.upsertAll([occurrence()]);
      final installationStore = _FakeInstallationStore();
      final service = NotificationOccurrenceSyncService(
        api: _FakeApi(NotificationOccurrenceApiResult.reRegister),
        store: store,
        installationStore: installationStore,
      );

      final result = await service.syncPending();

      expect(result, NotificationOccurrenceSyncResult.reRegister);
      expect(installationStore.registered, isFalse);
      expect(await store.pendingOccurrences(), hasLength(1));
    },
  );

  test(
    'disabled installation loss safely acknowledges local tombstones',
    () async {
      final store = NotificationOccurrenceStore();
      await store.upsertAll([occurrence()]);
      final service = NotificationOccurrenceSyncService(
        api: _FakeApi(NotificationOccurrenceApiResult.reRegister),
        store: store,
        installationStore: _FakeInstallationStore(),
      );

      final result = await service.syncPending(
        installationAbsenceIsSuccess: true,
      );

      expect(result, NotificationOccurrenceSyncResult.success);
      expect(await store.pendingOccurrences(), isEmpty);
    },
  );

  test('invalid rows are nonretryable and do not enqueue repair', () async {
    final store = NotificationOccurrenceStore();
    await store.upsertAll([occurrence()]);
    var repairs = 0;
    final service = NotificationOccurrenceSyncService(
      api: _FakeApi(NotificationOccurrenceApiResult.invalid),
      store: store,
      installationStore: _FakeInstallationStore(),
    );

    final result = await service.syncNowAndEnqueueOnRetry(
      enqueueRepair: () async => repairs++,
    );

    expect(result, NotificationOccurrenceSyncResult.invalid);
    expect(repairs, 0);
    expect(await store.pendingOccurrences(), isEmpty);
  });

  test('retryable failure enqueues once without recursively syncing', () async {
    final store = NotificationOccurrenceStore();
    await store.upsertAll([occurrence()]);
    final api = _FakeApi(NotificationOccurrenceApiResult.retry);
    var repairs = 0;
    final service = NotificationOccurrenceSyncService(
      api: api,
      store: store,
      installationStore: _FakeInstallationStore(),
    );

    final result = await service.syncNowAndEnqueueOnRetry(
      enqueueRepair: () async => repairs++,
    );

    expect(result, NotificationOccurrenceSyncResult.retry);
    expect(api.calls, 1);
    expect(repairs, 1);
    expect(await store.pendingOccurrences(), hasLength(1));
  });

  test(
    'onboarding and settings sync installation before armed occurrences',
    () async {
      final calls = <String>[];
      final coordinator = NotificationScheduleSyncCoordinator(
        syncInstallation: () async {
          calls.add('installation');
          return true;
        },
        syncOccurrences: () async {
          calls.add('occurrences');
          return NotificationOccurrenceSyncResult.retry;
        },
        enqueueRepair: () async => calls.add('repair'),
      );

      final synchronized = await coordinator.syncNow();

      expect(synchronized, isFalse);
      expect(calls, ['installation', 'occurrences', 'repair']);
    },
  );

  test('immediate retry plumbing never fails local settings success', () async {
    final coordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () async => throw StateError('firebase unavailable'),
      syncOccurrences: () async => throw StateError('network unavailable'),
      enqueueRepair: () async => throw StateError('workmanager unavailable'),
    );

    expect(await coordinator.syncNow(), isFalse);
  });

  test('occurrence persistence failure forces background repair', () async {
    var repairs = 0;
    final coordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () async => true,
      syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
      enqueueRepair: () async => repairs++,
    );

    expect(await coordinator.syncNow(forceRepair: true), isTrue);
    expect(repairs, 1);
  });

  test('durable UI handoff does not await unresolved network', () async {
    final installation = Completer<bool>();
    var installationStarted = false;
    final coordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () {
        installationStarted = true;
        return installation.future;
      },
      syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
      enqueueRepair: () async {},
    );

    await coordinator.dispatch();

    expect(installationStarted, isTrue);
    expect(installation.isCompleted, isFalse);
    expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);
  });

  test('successful detached sync clears durable handoff', () async {
    final installation = Completer<bool>();
    final coordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () => installation.future,
      syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
      enqueueRepair: () async {},
    );

    await coordinator.dispatch();
    expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);

    installation.complete(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(await NotificationRepairOutbox().hasPendingRepair, isFalse);
  });

  test('an older detached sync cannot clear a newer handoff', () async {
    final first = Completer<bool>();
    final second = Completer<bool>();
    final firstCoordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () => first.future,
      syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
      enqueueRepair: () async {},
    );
    final secondCoordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () => second.future,
      syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
      enqueueRepair: () async {},
    );

    await firstCoordinator.dispatch();
    await secondCoordinator.dispatch();
    first.complete(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);
    second.complete(false);
  });

  test(
    'forced local repair is enqueued before detached network completes',
    () async {
      final installation = Completer<bool>();
      var repairs = 0;
      final coordinator = NotificationScheduleSyncCoordinator(
        syncInstallation: () => installation.future,
        syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
        enqueueRepair: () async => repairs++,
      );

      await coordinator.dispatch(forceRepair: true);
      await Future<void>.delayed(Duration.zero);

      expect(repairs, 1);
      expect(installation.isCompleted, isFalse);
      expect(await NotificationRepairOutbox().hasPendingRepair, isTrue);
    },
  );

  test('forced retry coalesces repair registration', () async {
    var repairs = 0;
    final coordinator = NotificationScheduleSyncCoordinator(
      syncInstallation: () async => false,
      syncOccurrences: () async => NotificationOccurrenceSyncResult.retry,
      enqueueRepair: () async => repairs++,
    );

    await coordinator.dispatch(forceRepair: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(repairs, 1);
  });

  test(
    'disabled settings reconcile occurrences before disabling installation',
    () async {
      final calls = <String>[];
      final coordinator = NotificationScheduleSyncCoordinator(
        syncInstallation: () async {
          calls.add('installation');
          return true;
        },
        syncOccurrences: () async {
          calls.add('occurrences');
          return NotificationOccurrenceSyncResult.success;
        },
        enqueueRepair: () async {},
      );

      expect(await coordinator.syncNow(installationFirst: false), isTrue);
      expect(calls, ['occurrences', 'installation']);
    },
  );

  test(
    'disabled settings keep installation alive while reconciliation retries',
    () async {
      var installationCalls = 0;
      final coordinator = NotificationScheduleSyncCoordinator(
        syncInstallation: () async {
          installationCalls++;
          return true;
        },
        syncOccurrences: () async => NotificationOccurrenceSyncResult.retry,
        enqueueRepair: () async {},
      );

      expect(await coordinator.syncNow(installationFirst: false), isFalse);
      expect(installationCalls, 0);
    },
  );
}

class _FakeApi extends NotificationOccurrenceApi {
  _FakeApi(this.result);

  final NotificationOccurrenceApiResult result;
  int calls = 0;
  List<NotificationOccurrence> occurrences = const [];
  List<NotificationOccurrenceEvent> events = const [];

  @override
  Future<NotificationOccurrenceApiResult> putAll(
    NotificationInstallationCredentials credentials,
    List<NotificationOccurrence> occurrences, {
    List<NotificationOccurrenceEvent> events = const [],
    NotificationOccurrenceBatchResultHandler? onBatchResult,
  }) async {
    calls++;
    this.occurrences = occurrences;
    this.events = events;
    await onBatchResult?.call(occurrences, events, result);
    return result;
  }
}

class _FakeInstallationStore extends NotificationInstallationStore {
  bool registered = true;

  @override
  Future<NotificationInstallationCredentials> credentials() async =>
      const NotificationInstallationCredentials(
        installationId: '123e4567-e89b-42d3-a456-426614174000',
        registrationSecret: 'secret',
      );

  @override
  Future<void> markRegistered(bool value) async => registered = value;
}
