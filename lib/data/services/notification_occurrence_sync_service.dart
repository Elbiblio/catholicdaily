import 'dart:async';

import 'notification_installation_store.dart';
import 'notification_occurrence.dart';
import 'notification_occurrence_api.dart';
import 'notification_occurrence_store.dart';

enum NotificationOccurrenceSyncResult { success, reRegister, invalid, retry }

class NotificationScheduleSyncCoordinator {
  const NotificationScheduleSyncCoordinator({
    required this.syncInstallation,
    required this.syncOccurrences,
    required this.enqueueRepair,
  });

  final Future<bool> Function() syncInstallation;
  final Future<NotificationOccurrenceSyncResult> Function() syncOccurrences;
  final Future<void> Function() enqueueRepair;

  void dispatch({bool installationFirst = true, bool forceRepair = false}) {
    unawaited(
      _runDetached(
        installationFirst: installationFirst,
        forceRepair: forceRepair,
      ),
    );
  }

  Future<void> _runDetached({
    required bool installationFirst,
    required bool forceRepair,
  }) async {
    try {
      await syncNow(
        installationFirst: installationFirst,
        forceRepair: forceRepair,
      );
    } catch (_) {
      try {
        await enqueueRepair();
      } catch (_) {
        // Detached synchronization must never escape into the UI zone.
      }
    }
  }

  Future<bool> syncNow({
    bool installationFirst = true,
    bool forceRepair = false,
  }) async {
    var installationSynchronized = false;
    var occurrenceResult = NotificationOccurrenceSyncResult.retry;
    try {
      if (installationFirst) {
        installationSynchronized = await syncInstallation();
        if (installationSynchronized) {
          occurrenceResult = await syncOccurrences();
        }
      } else {
        occurrenceResult = await syncOccurrences();
        if (occurrenceResult == NotificationOccurrenceSyncResult.success ||
            occurrenceResult == NotificationOccurrenceSyncResult.invalid) {
          installationSynchronized = await syncInstallation();
        }
      }
    } catch (_) {
      installationSynchronized = false;
      occurrenceResult = NotificationOccurrenceSyncResult.retry;
    }
    final occurrenceSynchronized =
        occurrenceResult == NotificationOccurrenceSyncResult.success ||
        occurrenceResult == NotificationOccurrenceSyncResult.invalid;
    if (forceRepair || !installationSynchronized || !occurrenceSynchronized) {
      try {
        await enqueueRepair();
      } catch (_) {
        // Scheduling remains successful even when the OS cannot register work.
      }
    }
    return installationSynchronized && occurrenceSynchronized;
  }
}

class NotificationOccurrenceSyncService {
  NotificationOccurrenceSyncService({
    NotificationOccurrenceApi? api,
    NotificationOccurrenceStore? store,
    NotificationInstallationStore? installationStore,
  }) : _api = api ?? NotificationOccurrenceApi(),
       _store = store ?? NotificationOccurrenceStore(),
       _installationStore =
           installationStore ?? NotificationInstallationStore();

  static final NotificationOccurrenceSyncService instance =
      NotificationOccurrenceSyncService();

  final NotificationOccurrenceApi _api;
  final NotificationOccurrenceStore _store;
  final NotificationInstallationStore _installationStore;

  Future<NotificationOccurrenceSyncResult> syncPending({
    DateTime? synchronizedAt,
    bool installationAbsenceIsSuccess = false,
  }) async {
    try {
      final occurrences = await _store.pendingOccurrences();
      final events = await _store.pendingEvents();
      if (occurrences.isEmpty && events.isEmpty) {
        return NotificationOccurrenceSyncResult.success;
      }
      final credentials = await _installationStore.credentials();
      final apiResult = await _api.putAll(
        credentials,
        occurrences,
        events: events,
        onBatchResult: (batchOccurrences, batchEvents, result) async {
          if (result == NotificationOccurrenceApiResult.success ||
              result == NotificationOccurrenceApiResult.invalid) {
            await _markSent(batchOccurrences, batchEvents, synchronizedAt);
          }
        },
      );
      switch (apiResult) {
        case NotificationOccurrenceApiResult.success:
          return NotificationOccurrenceSyncResult.success;
        case NotificationOccurrenceApiResult.invalid:
          return (await _store.pendingOccurrences()).isEmpty &&
                  (await _store.pendingEvents()).isEmpty
              ? NotificationOccurrenceSyncResult.invalid
              : NotificationOccurrenceSyncResult.retry;
        case NotificationOccurrenceApiResult.reRegister:
          await _installationStore.markRegistered(false);
          if (installationAbsenceIsSuccess) {
            await _markSent(occurrences, events, synchronizedAt);
            return NotificationOccurrenceSyncResult.success;
          }
          return NotificationOccurrenceSyncResult.reRegister;
        case NotificationOccurrenceApiResult.retry:
          return NotificationOccurrenceSyncResult.retry;
      }
    } catch (_) {
      return NotificationOccurrenceSyncResult.retry;
    }
  }

  Future<NotificationOccurrenceSyncResult> reconcileAndSyncPending({
    DateTime? now,
    bool installationAbsenceIsSuccess = false,
  }) async {
    final auditTime = now ?? DateTime.now();
    try {
      await _store.reconcileExpired(now: auditTime);
      final result = await syncPending(
        synchronizedAt: auditTime,
        installationAbsenceIsSuccess: installationAbsenceIsSuccess,
      );
      if (result == NotificationOccurrenceSyncResult.success ||
          result == NotificationOccurrenceSyncResult.invalid) {
        await _store.prune(now: auditTime);
      }
      return result;
    } catch (_) {
      return NotificationOccurrenceSyncResult.retry;
    }
  }

  Future<void> reconcileLocalArming({
    required Set<String> pendingOccurrenceKeys,
    required DateTime reconciledAt,
  }) => _store.reconcileLocalArming(
    pendingOccurrenceKeys: pendingOccurrenceKeys,
    reconciledAt: reconciledAt,
  );

  Future<NotificationOccurrenceSyncResult> syncNowAndEnqueueOnRetry({
    required Future<void> Function() enqueueRepair,
  }) async {
    final result = await syncPending();
    if (result == NotificationOccurrenceSyncResult.retry ||
        result == NotificationOccurrenceSyncResult.reRegister) {
      try {
        await enqueueRepair();
      } catch (_) {
        // Local scheduling/settings success must not be converted into a UI
        // failure when background work registration is unavailable.
      }
    }
    return result;
  }

  Future<void> recordReceived(String occurrenceKey, DateTime occurredAt) =>
      _record(
        occurrenceKey,
        NotificationOccurrenceEventType.received,
        occurredAt,
      );

  Future<void> recordOpened(String occurrenceKey, DateTime occurredAt) =>
      _record(
        occurrenceKey,
        NotificationOccurrenceEventType.opened,
        occurredAt,
      );

  Future<void> recordExpired(String occurrenceKey, DateTime occurredAt) =>
      _record(
        occurrenceKey,
        NotificationOccurrenceEventType.expired,
        occurredAt,
      );

  Future<void> recordReconciled(String occurrenceKey, DateTime occurredAt) =>
      _record(
        occurrenceKey,
        NotificationOccurrenceEventType.reconciled,
        occurredAt,
      );

  Future<void> _record(
    String occurrenceKey,
    NotificationOccurrenceEventType type,
    DateTime occurredAt,
  ) => _store.recordEvent(
    NotificationOccurrenceEvent(
      occurrenceKey: occurrenceKey,
      type: type,
      occurredAt: occurredAt,
    ),
  );

  Future<void> _markSent(
    List<NotificationOccurrence> occurrences,
    List<NotificationOccurrenceEvent> events,
    DateTime? synchronizedAt,
  ) => _store.markSynchronized(
    occurrences: occurrences,
    eventIds: events.map((event) => event.id),
    synchronizedAt: synchronizedAt ?? DateTime.now(),
  );
}
