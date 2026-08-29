import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_service.dart';
import 'feast_reminder_timezone.dart';
import 'liturgical_region_preference_service.dart';
import 'notification_installation_sync_service.dart';
import 'notification_occurrence_sync_service.dart';
import 'notification_repair_outbox.dart';

enum FeastReminderAuditDecision { skip, cleanup, current, repair }

enum FeastReminderRepairReason {
  occurrenceSync,
  exactAlarmCapabilityChanged,
  timezoneChanged,
  startup,
  periodicAudit,
}

class FeastReminderRepairRequest {
  const FeastReminderRepairRequest({
    required this.reason,
    required this.forceReschedule,
  });

  static const reasonInputKey = 'repairReason';
  static const forceRescheduleInputKey = 'forceReschedule';

  final FeastReminderRepairReason reason;
  final bool forceReschedule;

  factory FeastReminderRepairRequest.fromWorkmanager(
    String task,
    Map<String, dynamic>? inputData,
  ) {
    final rawReason = inputData?[reasonInputKey];
    final reason = FeastReminderRepairReason.values.firstWhere(
      (candidate) => candidate.name == rawReason,
      orElse: () => task == FeastReminderBackgroundService.taskName
          ? FeastReminderRepairReason.periodicAudit
          : FeastReminderRepairReason.occurrenceSync,
    );
    final reasonForcesReschedule =
        reason == FeastReminderRepairReason.exactAlarmCapabilityChanged ||
        reason == FeastReminderRepairReason.timezoneChanged;
    return FeastReminderRepairRequest(
      reason: reason,
      forceReschedule:
          inputData?[forceRescheduleInputKey] == true || reasonForcesReschedule,
    );
  }

  Map<String, dynamic> toInputData() => <String, dynamic>{
    reasonInputKey: reason.name,
    forceRescheduleInputKey: forceReschedule,
  };
}

class NotificationStartupSyncDispatcher {
  NotificationStartupSyncDispatcher({
    required this.auditAndRepair,
    required this.initializeMessaging,
    required this.enqueueRepair,
    NotificationRepairOutbox? repairOutbox,
  }) : _repairOutbox = repairOutbox ?? NotificationRepairOutbox.instance;

  final Future<bool> Function() auditAndRepair;
  final Future<void> Function() initializeMessaging;
  final Future<void> Function() enqueueRepair;
  final NotificationRepairOutbox _repairOutbox;
  Future<void>? _repairRequest;

  Future<void> dispatch() async {
    String? repairToken;
    try {
      repairToken = await _repairOutbox.markPending(reason: 'startup');
    } catch (_) {
      // Startup remains available; detached repair registration is fallback.
    }
    unawaited(_runAudit(repairToken));
    unawaited(_runMessaging());
  }

  Future<void> _runAudit(String? repairToken) async {
    try {
      final succeeded = await auditAndRepair();
      if (succeeded) {
        try {
          if (repairToken != null) {
            await _repairOutbox.clear(ifToken: repairToken);
          }
        } catch (_) {
          // A retained marker safely asks the next startup to retry.
        }
        return;
      }
    } catch (_) {
      // Startup continues while the one-off repair owns recovery.
    }
    await _requestRepair();
  }

  Future<void> _requestRepair() => _repairRequest ??= _requestRepairOnce();

  Future<void> _requestRepairOnce() async {
    try {
      await _repairOutbox.markPending(reason: 'startup-retry');
      await enqueueRepair();
    } catch (_) {
      // Work registration is best-effort and cannot fail app startup.
    }
  }

  Future<void> _runMessaging() async {
    try {
      await initializeMessaging();
    } catch (_) {
      await _requestRepair();
    }
  }
}

class NotificationBackgroundSyncPolicy {
  const NotificationBackgroundSyncPolicy();

  bool succeeded({
    required bool installationSynchronized,
    required NotificationOccurrenceSyncResult occurrenceResult,
  }) =>
      installationSynchronized &&
      (occurrenceResult == NotificationOccurrenceSyncResult.success ||
          occurrenceResult == NotificationOccurrenceSyncResult.invalid);
}

class FeastReminderAuditSnapshot {
  const FeastReminderAuditSnapshot({
    required this.enabled,
    required this.permissionGranted,
    required this.schemaVersion,
    required this.scheduleGeneration,
    required this.scheduledTimezone,
    required this.currentTimezone,
    required this.scheduledThrough,
    required this.scheduleInProgress,
    required this.hasCancellationState,
    required this.scheduledConfigurationFingerprint,
    required this.currentConfigurationFingerprint,
  });

  final bool enabled;
  final bool permissionGranted;
  final int schemaVersion;
  final String? scheduleGeneration;
  final String? scheduledTimezone;
  final String currentTimezone;
  final DateTime? scheduledThrough;
  final bool scheduleInProgress;
  final bool hasCancellationState;
  final String? scheduledConfigurationFingerprint;
  final String currentConfigurationFingerprint;

  FeastReminderAuditSnapshot copyWith({
    bool? enabled,
    bool? permissionGranted,
    int? schemaVersion,
    String? scheduleGeneration,
    String? scheduledTimezone,
    String? currentTimezone,
    DateTime? scheduledThrough,
    bool? scheduleInProgress,
    bool? hasCancellationState,
    String? scheduledConfigurationFingerprint,
    String? currentConfigurationFingerprint,
  }) => FeastReminderAuditSnapshot(
    enabled: enabled ?? this.enabled,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    scheduleGeneration: scheduleGeneration ?? this.scheduleGeneration,
    scheduledTimezone: scheduledTimezone ?? this.scheduledTimezone,
    currentTimezone: currentTimezone ?? this.currentTimezone,
    scheduledThrough: scheduledThrough ?? this.scheduledThrough,
    scheduleInProgress: scheduleInProgress ?? this.scheduleInProgress,
    hasCancellationState: hasCancellationState ?? this.hasCancellationState,
    scheduledConfigurationFingerprint:
        scheduledConfigurationFingerprint ??
        this.scheduledConfigurationFingerprint,
    currentConfigurationFingerprint:
        currentConfigurationFingerprint ?? this.currentConfigurationFingerprint,
  );
}

class FeastReminderAuditPolicy {
  const FeastReminderAuditPolicy({
    required this.expectedSchemaVersion,
    required this.expectedScheduleGeneration,
    this.minimumCoverage = const Duration(days: 30),
  });

  final int expectedSchemaVersion;
  final String expectedScheduleGeneration;
  final Duration minimumCoverage;

  FeastReminderAuditDecision decide(
    FeastReminderAuditSnapshot snapshot, {
    required DateTime now,
    bool forceReschedule = false,
  }) {
    if (!snapshot.enabled || !snapshot.permissionGranted) {
      return snapshot.scheduleInProgress || snapshot.hasCancellationState
          ? FeastReminderAuditDecision.cleanup
          : FeastReminderAuditDecision.skip;
    }
    final coverageThreshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(minimumCoverage);
    if (forceReschedule ||
        snapshot.scheduleInProgress ||
        snapshot.schemaVersion != expectedSchemaVersion ||
        snapshot.scheduleGeneration != expectedScheduleGeneration ||
        snapshot.scheduledTimezone != snapshot.currentTimezone ||
        snapshot.scheduledConfigurationFingerprint !=
            snapshot.currentConfigurationFingerprint ||
        snapshot.scheduledThrough == null ||
        snapshot.scheduledThrough!.isBefore(coverageThreshold)) {
      return FeastReminderAuditDecision.repair;
    }
    return FeastReminderAuditDecision.current;
  }
}

@pragma('vm:entry-point')
void feastReminderWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final request = FeastReminderRepairRequest.fromWorkmanager(task, inputData);
    return FeastReminderBackgroundService.instance.auditAndRepair(
      forceReschedule: request.forceReschedule,
    );
  });
}

class FeastReminderBackgroundService {
  FeastReminderBackgroundService._();

  static final FeastReminderBackgroundService instance =
      FeastReminderBackgroundService._();

  static const periodicWorkName = 'feast-reminder-coverage-audit';
  static const repairWorkName = 'feast-reminder-coverage-repair';
  static const taskName = 'audit-feast-reminder-coverage';
  static const _scheduleMonths = 15;
  static const _policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: FeastReminderService.scheduleSchemaVersion,
    expectedScheduleGeneration:
        FeastReminderNotificationContract.scheduleGeneration,
  );
  static const _notificationSyncPolicy = NotificationBackgroundSyncPolicy();

  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    await Workmanager().initialize(feastReminderWorkmanagerDispatcher);
    await Workmanager().registerPeriodicTask(
      periodicWorkName,
      taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    _initialized = true;
  }

  Future<void> enqueueRepair({
    FeastReminderRepairReason reason = FeastReminderRepairReason.occurrenceSync,
  }) async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().registerOneOffTask(
      repairWorkName,
      taskName,
      inputData: FeastReminderRepairRequest(
        reason: reason,
        forceReschedule:
            reason == FeastReminderRepairReason.exactAlarmCapabilityChanged ||
            reason == FeastReminderRepairReason.timezoneChanged,
      ).toInputData(),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  Future<bool> auditAndRepair({bool forceReschedule = false}) async {
    String? repairToken;
    try {
      repairToken = await NotificationRepairOutbox.instance.pendingToken;
      final succeeded = await _auditAndRepair(forceReschedule: forceReschedule);
      if (succeeded) {
        try {
          if (repairToken != null) {
            await NotificationRepairOutbox.instance.clear(ifToken: repairToken);
          }
        } catch (_) {
          // A retained marker safely causes a later reconciliation.
        }
      }
      return succeeded;
    } catch (error, stackTrace) {
      debugPrint(
        '[FeastReminder] Background coverage audit failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  Future<bool> _auditAndRepair({required bool forceReschedule}) async {
    final prefs = await FeastReminderPreferences.getInstance();
    await prefs.reload();
    final now = DateTime.now();
    final reminders = FeastReminderService.instance;
    if (!prefs.isEnabled) {
      if (prefs.hasCancellationState) {
        final occurrenceQueuePersisted = await reminders.cancelAll();
        if (!occurrenceQueuePersisted) return false;
      }
      await prefs.setLastAuditAt(now);
      return _syncRemoteState(now, remindersEnabled: false);
    }

    final timezone = await FeastReminderTimezone.configure();
    await reminders.initialize();
    final permissionGranted = await reminders.hasPermission();
    final regionPreferences =
        await LiturgicalRegionPreferenceService.getInstance();
    final currentConfiguration = prefs.configurationFingerprint(
      region: regionPreferences.currentRegion.name,
    );
    final decision = _policy.decide(
      FeastReminderAuditSnapshot(
        enabled: prefs.isEnabled,
        permissionGranted: permissionGranted,
        schemaVersion: prefs.scheduleSchemaVersion,
        scheduleGeneration: prefs.scheduleGeneration,
        scheduledTimezone: prefs.scheduleTimezone,
        currentTimezone: timezone,
        scheduledThrough: prefs.scheduledThrough,
        scheduleInProgress: prefs.scheduleInProgress,
        hasCancellationState: prefs.hasCancellationState,
        scheduledConfigurationFingerprint:
            prefs.scheduledConfigurationFingerprint,
        currentConfigurationFingerprint: currentConfiguration,
      ),
      now: now,
      forceReschedule: forceReschedule,
    );
    var needsLocalScheduleRepair = false;

    if (decision == FeastReminderAuditDecision.cleanup) {
      final occurrenceQueuePersisted = await reminders.cancelAll();
      if (!occurrenceQueuePersisted) return false;
      await prefs.setLastAuditAt(now);
    } else if (decision == FeastReminderAuditDecision.repair) {
      final result = await reminders.scheduleAheadMonths(
        _scheduleMonths,
        prefs,
      );
      if (!result.canSyncServerOnlyOccurrences) {
        return false;
      }
      needsLocalScheduleRepair = result.needsLocalScheduleRepair;
    } else {
      await prefs.setLastAuditAt(now);
    }

    final pendingOccurrenceKeys = await reminders.pendingOccurrenceKeys();
    if (pendingOccurrenceKeys != null) {
      await NotificationOccurrenceSyncService.instance.reconcileLocalArming(
        pendingOccurrenceKeys: pendingOccurrenceKeys,
        reconciledAt: now,
      );
    }

    final remoteSynchronized = await _syncRemoteState(
      now,
      remindersEnabled: true,
    );
    return remoteSynchronized && !needsLocalScheduleRepair;
  }

  Future<bool> _syncRemoteState(
    DateTime now, {
    required bool remindersEnabled,
  }) async {
    // Occurrence sync never enqueues work itself; returning false lets the
    // current Workmanager run own the retry without recursion.
    final occurrenceResult = await NotificationOccurrenceSyncService.instance
        .reconcileAndSyncPending(
          now: now,
          installationAbsenceIsSuccess: !remindersEnabled,
        );
    if (!remindersEnabled &&
        occurrenceResult != NotificationOccurrenceSyncResult.success &&
        occurrenceResult != NotificationOccurrenceSyncResult.invalid) {
      return false;
    }
    final installationSynchronized = await NotificationInstallationSyncService
        .instance
        .syncCurrentToken();
    return _notificationSyncPolicy.succeeded(
      installationSynchronized: installationSynchronized,
      occurrenceResult: occurrenceResult,
    );
  }
}
