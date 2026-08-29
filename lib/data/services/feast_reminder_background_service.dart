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
  timeSet,
  bootCompleted,
  packageReplaced,
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
      orElse: () {
        if (task ==
            FeastReminderBackgroundService.iosForcedRepairTaskIdentifier) {
          return FeastReminderRepairReason.exactAlarmCapabilityChanged;
        }
        return task == FeastReminderBackgroundService.taskName
            ? FeastReminderRepairReason.periodicAudit
            : FeastReminderRepairReason.occurrenceSync;
      },
    );
    final reasonForcesReschedule =
        reason == FeastReminderRepairReason.exactAlarmCapabilityChanged ||
        reason == FeastReminderRepairReason.timezoneChanged ||
        reason == FeastReminderRepairReason.timeSet ||
        reason == FeastReminderRepairReason.bootCompleted ||
        reason == FeastReminderRepairReason.packageReplaced;
    final taskForcesReschedule =
        task == FeastReminderBackgroundService.iosForcedRepairTaskIdentifier;
    return FeastReminderRepairRequest(
      reason: reason,
      forceReschedule:
          inputData?[forceRescheduleInputKey] == true ||
          reasonForcesReschedule ||
          taskForcesReschedule,
    );
  }

  Map<String, dynamic> toInputData() => <String, dynamic>{
    reasonInputKey: reason.name,
    forceRescheduleInputKey: forceReschedule,
  };
}

class NotificationBackgroundAuditRunner {
  NotificationBackgroundAuditRunner({
    required Future<bool> Function(bool forceReschedule) audit,
    required Future<void> Function(FeastReminderRepairRequest request)
    enqueueRepair,
    required bool isIos,
    NotificationRepairOutbox? repairOutbox,
    void Function(Object error, StackTrace stackTrace)? onAuditError,
  }) : _audit = audit,
       _enqueueRepair = enqueueRepair,
       _isIos = isIos,
       _repairOutbox = repairOutbox ?? NotificationRepairOutbox.instance,
       _onAuditError = onAuditError;

  final Future<bool> Function(bool forceReschedule) _audit;
  final Future<void> Function(FeastReminderRepairRequest request)
  _enqueueRepair;
  final bool _isIos;
  final NotificationRepairOutbox _repairOutbox;
  final void Function(Object error, StackTrace stackTrace)? _onAuditError;
  final Map<bool, Future<void>> _repairRegistrations = <bool, Future<void>>{};
  Future<void>? _markerWrite;

  Future<bool> run(FeastReminderRepairRequest request) async {
    String? repairToken;
    try {
      repairToken = await _repairOutbox.pendingToken;
    } catch (_) {
      // A corrupt/unreadable marker stays pending and cannot be cleared here.
    }

    var succeeded = false;
    try {
      succeeded = await _audit(request.forceReschedule);
    } catch (error, stackTrace) {
      _onAuditError?.call(error, stackTrace);
    }

    if (succeeded) {
      if (repairToken != null) {
        try {
          await _repairOutbox.clear(ifToken: repairToken);
        } catch (_) {
          // A retained marker safely causes a later reconciliation.
        }
      }
      return true;
    }

    // Android WorkManager retries a false task result. iOS BGProcessing tasks
    // are one-shot, so failure must submit a replacement request explicitly.
    if (!_isIos) return false;
    await _retainPendingMarker(request);
    try {
      await _enqueueRepairCoalesced(_normalizedRetryRequest(request));
    } catch (_) {
      // Registration failure leaves the outbox marker for startup recovery.
    }
    return false;
  }

  FeastReminderRepairRequest _normalizedRetryRequest(
    FeastReminderRepairRequest request,
  ) {
    if (!request.forceReschedule ||
        request.reason ==
            FeastReminderRepairReason.exactAlarmCapabilityChanged ||
        request.reason == FeastReminderRepairReason.timezoneChanged) {
      return request;
    }
    return const FeastReminderRepairRequest(
      reason: FeastReminderRepairReason.exactAlarmCapabilityChanged,
      forceReschedule: true,
    );
  }

  Future<void> _retainPendingMarker(FeastReminderRepairRequest request) async {
    final existing = _markerWrite;
    if (existing != null) return existing;
    final write = _writeMarkerIfMissing(request);
    _markerWrite = write;
    try {
      await write;
    } finally {
      if (identical(_markerWrite, write)) _markerWrite = null;
    }
  }

  Future<void> _writeMarkerIfMissing(FeastReminderRepairRequest request) async {
    try {
      if (!await _repairOutbox.hasPendingRepair) {
        await _repairOutbox.markPending(
          reason: 'ios-background-${request.reason.name}',
        );
      }
    } catch (_) {
      // The BGProcessing registration still provides a durable retry attempt.
    }
  }

  Future<void> _enqueueRepairCoalesced(
    FeastReminderRepairRequest request,
  ) async {
    final key = request.forceReschedule;
    final existing = _repairRegistrations[key];
    if (existing != null) return existing;
    final registration = _enqueueRepair(request);
    _repairRegistrations[key] = registration;
    try {
      await registration;
    } finally {
      if (identical(_repairRegistrations[key], registration)) {
        _repairRegistrations.remove(key);
      }
    }
  }
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
  Future<void>? _messagingRequest;

  Future<void> dispatch() async {
    // Foreground delivery and token listeners do not depend on background-work
    // availability. Their initialization is independently error-isolated and
    // coalesced when startup dispatch is requested more than once.
    unawaited(_initializeMessagingOnce());
    String? repairToken;
    try {
      repairToken = await _repairOutbox.markPending(reason: 'startup');
    } catch (_) {
      // Startup remains available; detached repair registration is fallback.
    }
    try {
      await _requestRepair();
    } catch (_) {
      // Never detach work that has no durable executor. The outbox remains for
      // a later startup, and already-armed local alarms remain unaffected.
      return;
    }
    unawaited(_runAudit(repairToken));
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

  Future<void> _requestRepair() => _repairRequest ??= enqueueRepair();

  Future<void> _initializeMessagingOnce() =>
      _messagingRequest ??= _runMessaging();

  Future<void> _runMessaging() async {
    try {
      await initializeMessaging();
    } catch (_) {
      try {
        await _requestRepair();
      } catch (_) {
        // Messaging and executor failures are isolated from app startup.
      }
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
      repairReason: request.reason,
    );
  });
}

class FeastReminderBackgroundService {
  FeastReminderBackgroundService._() {
    _auditRunner = NotificationBackgroundAuditRunner(
      audit: (forceReschedule) =>
          _auditAndRepair(forceReschedule: forceReschedule),
      enqueueRepair: (request) => enqueueRepair(reason: request.reason),
      isIos: Platform.isIOS,
      onAuditError: (error, stackTrace) {
        debugPrint(
          '[FeastReminder] Background coverage audit failed: '
          '$error\n$stackTrace',
        );
      },
    );
  }

  static final FeastReminderBackgroundService instance =
      FeastReminderBackgroundService._();

  static const periodicWorkName = 'feast-reminder-coverage-audit';
  static const repairWorkName = 'feast-reminder-coverage-repair';
  static const taskName = 'audit-feast-reminder-coverage';
  static const iosRepairTaskIdentifier =
      'com.elbiblio.catholicdaily.notification-repair';
  static const iosForcedRepairTaskIdentifier =
      'com.elbiblio.catholicdaily.notification-repair-forced';
  static const _scheduleMonths = 15;
  static const _policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: FeastReminderService.scheduleSchemaVersion,
    expectedScheduleGeneration:
        FeastReminderNotificationContract.scheduleGeneration,
  );
  static const _notificationSyncPolicy = NotificationBackgroundSyncPolicy();

  late final NotificationBackgroundAuditRunner _auditRunner;
  bool _initialized = false;

  Future<void> initialize() async {
    if ((!Platform.isAndroid && !Platform.isIOS) || _initialized) return;
    await Workmanager().initialize(feastReminderWorkmanagerDispatcher);
    if (Platform.isAndroid) {
      await Workmanager().registerPeriodicTask(
        periodicWorkName,
        taskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    }
    _initialized = true;
  }

  Future<void> enqueueRepair({
    FeastReminderRepairReason reason = FeastReminderRepairReason.occurrenceSync,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Durable notification repair is unavailable on '
        '${Platform.operatingSystem}',
      );
    }
    await initialize();
    final forceReschedule =
        reason == FeastReminderRepairReason.exactAlarmCapabilityChanged ||
        reason == FeastReminderRepairReason.timezoneChanged ||
        reason == FeastReminderRepairReason.timeSet ||
        reason == FeastReminderRepairReason.bootCompleted ||
        reason == FeastReminderRepairReason.packageReplaced;
    if (Platform.isIOS) {
      // Workmanager's iOS registerOneOffTask uses UIApplication background
      // time and cannot survive process death. BGProcessingTaskRequest is the
      // durable request type; native identifiers/handlers are declared in
      // Info.plist and AppDelegate.swift.
      final identifier = forceReschedule
          ? iosForcedRepairTaskIdentifier
          : iosRepairTaskIdentifier;
      await Workmanager().cancelByUniqueName(identifier);
      await Workmanager().registerProcessingTask(
        identifier,
        identifier,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
      return;
    }
    await Workmanager().registerOneOffTask(
      repairWorkName,
      taskName,
      inputData: FeastReminderRepairRequest(
        reason: reason,
        forceReschedule: forceReschedule,
      ).toInputData(),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  Future<bool> auditAndRepair({
    bool forceReschedule = false,
    FeastReminderRepairReason repairReason =
        FeastReminderRepairReason.periodicAudit,
  }) => _auditRunner.run(
    FeastReminderRepairRequest(
      reason: repairReason,
      forceReschedule: forceReschedule,
    ),
  );

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
